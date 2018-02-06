//
//  ChainableCommand.swift
//  ChainableCommands
//
//  Created by Nate Petersen on 1/28/18.
//  Copyright © 2018 Digital Rickshaw. All rights reserved.

import Foundation

/// A helpful wrapper that allows you to return either
/// the expected result, or an error.
public enum Result<Value> {
    case success(Value)
    case failure(Error)
}

/// If a command has no Input or no Output, it can specify this in the typealias.
public struct EmptyCommandData {}

public typealias ErrorHandler = (Error) -> ()
public typealias Continuation<Output> = (Output, @escaping ErrorHandler) -> ()

/// A protocol for chaining commands together. Each command has a defined Input and
/// Output type. You can chain two commands if the Output type of the first matches
/// the Input type of the second.
public protocol ChainableCommand: class {

    /// The Input type for this command. If no Input is required, use `EmptyCommandData` here.
    associatedtype Input

    /// The Output type for this command. If no Output is required, use `EmptyCommandData` here.
    associatedtype Output

    /// Holds the next command in the chain.
    var continuation: Continuation<Output>? { get set }

    /// Performs the logic of the command. This is the only function that
    /// conforming classes need to implement.
    ///
    /// - Parameters:
    ///   - input: The required input for the command.
    ///   - completion: A completion to execute when the command is finished.
    func main(_ input: Input, completion: @escaping (Result<Output>) -> ())

    /// Executes the command.
    ///
    /// - Parameters:
    ///   - input: The required input for the command.
    ///   - errorHandler: An `ErrorHandler` to execute if an error occurs.
    func execute(_ input: Input, errorHandler: @escaping ErrorHandler)

    /// Appends a new command to the chain.
    ///
    /// - Parameter nextCommand: A command whose input matches this command's output.
    /// - Returns: A `Chain` object, which you can essentially treat as a `ChainableCommand`.
    func append<C: ChainableCommand>(_ nextCommand: C) -> Chain<Self, C> where C.Input == Output
}

public extension ChainableCommand {

    /// Appends a new command to the chain.
    ///
    /// - Parameter nextCommand: A command whose input matches this command's output.
    /// - Returns: A `Chain` object, which you can essentially treat as a `ChainableCommand`.
    func append<C: ChainableCommand>(_ nextCommand: C) -> Chain<Self, C> where C.Input == Output {
        continuation = { (result: Output, errorHandler: @escaping ErrorHandler) in
            nextCommand.execute(result, errorHandler: errorHandler)
        }

        return Chain(first: self, last: nextCommand)
    }

    /// A convenience function that wraps a block in a `BlockCommand` and appends it.
    ///
    /// - Parameter block: A block to append.
    /// - Returns: A `Chain` object, which you can essentially treat as a `ChainableCommand`.
    func append<I, O>(_ block: @escaping (I) -> (Result<O>)) -> Chain<Self, BlockCommand<I,O>> where I == Output {
        return append(BlockCommand(block: block))
    }

    /// A convenience function that wraps a block with no return in a `BlockCommand` and appends it.
    ///
    /// - Parameter block: A block to append.
    /// - Returns: A `Chain` object, which you can essentially treat as a `ChainableCommand`.
    func append<I>(_ block: @escaping (I) -> ()) -> Chain<Self, BlockCommand<I,EmptyCommandData>> where I == Output {
        let wrapper: (I) -> (Result<EmptyCommandData>) = { (result) in
            block(result)
            return .success(EmptyCommandData())
        }

        return append(wrapper)
    }

    /// Executes the command.
    ///
    /// - Parameters:
    ///   - input: The required input for the command.
    ///   - errorHandler: An `ErrorHandler` to execute if an error occurs.
    func execute(_ input: Input, errorHandler: @escaping ErrorHandler) {
        // intentionally capture strong reference to self, to avoid being deallocated while executing
        var strongSelf : Self? = self

        main(input) { (result) in
            switch result {
            case .success(let output):
                guard let strongSelf = strongSelf else {
                    assertionFailure()
                    return
                }

                strongSelf.continuation?(output, errorHandler)

            case .failure(let error):
                errorHandler(error)
            }

            // clear strong reference
            strongSelf = nil
        }
    }
}

public extension ChainableCommand where Input == EmptyCommandData {

    /// A convenience function for executing a `ChainableCommand` that
    /// requires no input.
    ///
    /// - Parameter errorHandler: An `ErrorHandler` to execute if an error occurs.
    func execute(errorHandler: @escaping ErrorHandler) {
        execute(EmptyCommandData(), errorHandler: errorHandler)
    }
}

/// Wraps a block into a `ChainableCommand`.
public final class BlockCommand<ThisInput, ThisOutput>: ChainableCommand {
    public typealias Input = ThisInput
    public typealias Output = ThisOutput

    public var errorHandler: ErrorHandler?
    public var continuation: Continuation<Output>?

    private let block: (ThisInput) -> (Result<ThisOutput>)

    public init(block: @escaping (ThisInput) -> (Result<ThisOutput>)) {
        self.block = block
    }

    public func main(_ input: ThisInput, completion: @escaping (Result<ThisOutput>) -> ()) {
        let output = block(input)
        completion(output)
    }
}

/// A chain of `ChainableCommand` objects.
public struct Chain<FirstElement, LastElement> {
    public let first: FirstElement
    public let last: LastElement

    public init(first: FirstElement, last: LastElement) {
        self.first = first
        self.last = last
    }
}

public extension Chain where FirstElement: ChainableCommand, LastElement: ChainableCommand {
    /// Appends a new command to the chain.
    ///
    /// - Parameter nextCommand: A command whose input matches this command's output.
    /// - Returns: A `Chain` object, which you can essentially treat as a `ChainableCommand`.
    public func append<C: ChainableCommand>(_ nextCommand: C) -> Chain<FirstElement,C> where C.Input == LastElement.Output {
        return Chain<FirstElement,C>(first: first, last: last.append(nextCommand).last)
    }

    /// A convenience function that wraps a block in a `BlockCommand` and appends it.
    ///
    /// - Parameter block: A block to append.
    /// - Returns: A `Chain` object, which you can essentially treat as a `ChainableCommand`.
    func append<I, O>(_ block: @escaping (I) -> (Result<O>)) -> Chain<FirstElement, BlockCommand<I,O>> where I == LastElement.Output {
        return Chain<FirstElement,BlockCommand<I,O>>(first: first, last: last.append(BlockCommand(block: block)).last)
    }

    /// A convenience function that wraps a block with no return in a `BlockCommand` and appends it.
    ///
    /// - Parameter block: A block to append.
    /// - Returns: A `Chain` object, which you can essentially treat as a `ChainableCommand`.
    func append<I>(_ block: @escaping (I) -> ()) -> Chain<FirstElement, BlockCommand<I,EmptyCommandData>> where I == LastElement.Output {
        return Chain<FirstElement,BlockCommand<I,EmptyCommandData>>(first: first, last: last.append(block).last)
    }

    /// Executes the command chain.
    ///
    /// - Parameters:
    ///   - input: The required input for the first command.
    ///   - errorHandler: An `ErrorHandler` to execute if an error occurs.
    func execute(_ input: FirstElement.Input, errorHandler: @escaping ErrorHandler) {
        first.execute(input, errorHandler: errorHandler)
    }
}

public extension Chain where FirstElement: ChainableCommand, FirstElement.Input == EmptyCommandData {

    /// A convenience function for executing a command chain that
    /// requires no input.
    ///
    /// - Parameter errorHandler: An `ErrorHandler` to execute if an error occurs.
    func execute(errorHandler: @escaping ErrorHandler) {
        first.execute(EmptyCommandData(), errorHandler: errorHandler)
    }
}
