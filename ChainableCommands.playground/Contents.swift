//: Playground - noun: a place where people can play

import Foundation

enum FakeErrors: Error {
    case somethingBad
}

final class PrimingCommand: ChainableCommand {
    typealias Input = EmptyCommandData
    typealias Output = (Int, Int)

    var continuation: Continuation<Output>?

    let x: Int
    let y: Int

    init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }

    func main(_ input: EmptyCommandData, completion: @escaping (Result<(Int, Int)>) -> ()) {
        completion(.success((x, y)))
    }
}

final class AddCommand: ChainableCommand {
    typealias Input = (Int, Int)
    typealias Output = Int

    var continuation: Continuation<Output>?

    func main(_ input: (Int, Int), completion: @escaping (Result<Int>) -> ()) {
        let result = input.0 + input.1
        completion(.success(result))
    }
}

final class DoubleCommand: ChainableCommand {
    typealias Input = Int
    typealias Output = Int

    var continuation: Continuation<Output>?

    func main(_ input: Int, completion: @escaping (Result<Int>) -> ()) {
        let result = input * 2
        completion(.success(result))
//        completion(.failure(FakeErrors.somethingBad))
    }
}

final class PrintCommand: ChainableCommand {
    typealias Input = Int
    typealias Output = String

    var continuation: Continuation<Output>?

    func main(_ input: Int, completion: @escaping (Result<String>) -> ()) {
        let result = "This is the result: \(input)"
        print(result)
        completion(.success(result))
    }
}

PrimingCommand(x: 2, y: 3)
    .append(AddCommand())
    .append(DoubleCommand())
    .append { (input) -> Result<Int> in
        let result = input * 3
        return .success(result)
    }
    .append(PrintCommand())
    .append { (result) in
        print("I got the result: \"\(result)\"")
    }
    .execute { (error) in
        print("oops: \(error)")
    }


