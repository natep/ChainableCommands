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
public typealias Continuation<Output> = (Output) -> ()

public protocol ChainableCommand: class {
    associatedtype Input
    associatedtype Output

    var errorHandler: ErrorHandler? { get set }
    var continuation: Continuation<Output>? { get set }

    func main(_ input: Input, completion: @escaping (Result<Output>) -> ())

    func execute(_ input: Input)

    @discardableResult func append<C: ChainableCommand>(_ nextCommand: C) -> C where C.Input == Output
}

public extension ChainableCommand {
    func append<C: ChainableCommand>(_ nextCommand: C) -> C where C.Input == Output {
        continuation = { [weak self] (result) in
            nextCommand.errorHandler = self?.errorHandler
            nextCommand.execute(result)
        }

        return nextCommand
    }

    func append<I, O>(_ block: @escaping (I) -> (Result<O>)) -> BlockCommand<I,O> where I == Output {
        return append(BlockCommand(block: block))
    }

    func append<I>(_ block: @escaping (I) -> ()) -> BlockCommand<I,EmptyCommandData> where I == Output {
        let wrapper: (I) -> (Result<EmptyCommandData>) = { (result) in
            block(result)
            return .success(EmptyCommandData())
        }

        return append(wrapper)
    }

    func execute(_ input: Input) {
        main(input) { [weak self] (result) in
            switch result {
            case .success(let output):
                self?.continuation?(output)

            case .failure(let error):
                self?.errorHandler?(error)
            }
        }
    }
}

public extension ChainableCommand where Input == EmptyCommandData {
    func execute() {
        execute(EmptyCommandData())
    }
}

public class BlockCommand<ThisInput, ThisOutput>: ChainableCommand {
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
