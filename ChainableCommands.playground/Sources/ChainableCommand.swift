//
//  ChainableCommand.swift
//  ChainableCommands
//
//  Created by Nate Petersen on 1/28/18.
//  Copyright © 2018 Digital Rickshaw. All rights reserved.

import Foundation

public enum Result<Value> {
    case success(Value)
    case failure(Error)
}

public struct EmptyCommandData {}

public typealias ErrorHandler = (Error) -> ()
public typealias Continuation<Output> = (Output, @escaping ErrorHandler) -> ()

public protocol ChainableCommand: class {
    associatedtype Input
    associatedtype Output

    var continuation: Continuation<Output>? { get set }

    func main(_ input: Input, completion: @escaping (Result<Output>) -> ())

    func execute(_ input: Input, errorHandler: @escaping ErrorHandler)

    @discardableResult func append<C: ChainableCommand>(_ nextCommand: C) -> Chain<Self, C> where C.Input == Output
}

public extension ChainableCommand {
    func append<C: ChainableCommand>(_ nextCommand: C) -> Chain<Self, C> where C.Input == Output {
        continuation = { (result: Output, errorHandler: @escaping ErrorHandler) in
            nextCommand.execute(result, errorHandler: errorHandler)
        }

        return Chain(first: self, last: nextCommand)
    }

    func append<I, O>(_ block: @escaping (I) -> (Result<O>)) -> Chain<Self, BlockCommand<I,O>> where I == Output {
        return append(BlockCommand(block: block))
    }

    func append<I>(_ block: @escaping (I) -> ()) -> Chain<Self, BlockCommand<I,EmptyCommandData>> where I == Output {
        let wrapper: (I) -> (Result<EmptyCommandData>) = { (result) in
            block(result)
            return .success(EmptyCommandData())
        }

        return append(wrapper)
    }

    func execute(_ input: Input, errorHandler: @escaping ErrorHandler) {
        main(input) { [weak self] (result) in
            switch result {
            case .success(let output):
                self?.continuation?(output, errorHandler)

            case .failure(let error):
                errorHandler(error)
            }
        }
    }
}

public extension ChainableCommand where Input == EmptyCommandData {
    func execute(errorHandler: @escaping ErrorHandler) {
        execute(EmptyCommandData(), errorHandler: errorHandler)
    }
}

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

public struct Chain<FirstElement, LastElement> {
    public let first: FirstElement
    public let last: LastElement

    public init(first: FirstElement, last: LastElement) {
        self.first = first
        self.last = last
    }
}

public extension Chain where LastElement: ChainableCommand {
    public func append<C: ChainableCommand>(_ nextCommand: C) -> Chain<FirstElement,C> where C.Input == LastElement.Output {
        return Chain<FirstElement,C>(first: first, last: last.append(nextCommand).last)
    }
}

public extension Chain where FirstElement: ChainableCommand, LastElement: ChainableCommand {
    func append<I, O>(_ block: @escaping (I) -> (Result<O>)) -> Chain<FirstElement, BlockCommand<I,O>> where I == LastElement.Output {
        return Chain<FirstElement,BlockCommand<I,O>>(first: first, last: last.append(BlockCommand(block: block)).last)
    }

    func append<I>(_ block: @escaping (I) -> ()) -> Chain<FirstElement, BlockCommand<I,EmptyCommandData>> where I == LastElement.Output {
        return Chain<FirstElement,BlockCommand<I,EmptyCommandData>>(first: first, last: last.append(block).last)
    }
}

public extension Chain where FirstElement: ChainableCommand {
    func execute(_ input: FirstElement.Input, errorHandler: @escaping ErrorHandler) {
        first.execute(input, errorHandler: errorHandler)
    }
}

public extension Chain where FirstElement: ChainableCommand, FirstElement.Input == EmptyCommandData {
    func execute(errorHandler: @escaping ErrorHandler) {
        first.execute(EmptyCommandData(), errorHandler: errorHandler)
    }
}
