//: Playground - noun: a place where people can play

import Foundation

enum FakeErrors: Error {
    case somethingBad
}

/// An example command that takes an Int tuple as input and outputs a single Int.
final class AddCommand: ChainableCommand {
    typealias Input = (Int, Int)
    typealias Output = Int

    var continuation: Continuation<Output>?

    func main(_ input: (Int, Int), completion: @escaping (Result<Int>) -> ()) {
        let result = input.0 + input.1
        completion(.success(result))
    }
}

/// An example command that takes an Int as input and outputs an Int.
final class DoubleCommand: ChainableCommand {
    typealias Input = Int
    typealias Output = Int

    var continuation: Continuation<Output>?

    func main(_ input: Int, completion: @escaping (Result<Int>) -> ()) {
        let result = input * 2

        // comment out this line and uncomment the next to simulate an error
        completion(.success(result))
//        completion(.failure(FakeErrors.somethingBad))
    }
}

/// An example command that takes an Int as input and outputs a String.
final class PrintCommand: ChainableCommand {
    typealias Input = Int
    typealias Output = String

    var continuation: Continuation<Output>?

    func main(_ input: Int, completion: @escaping (Result<String>) -> ()) {
        let result = "This is the result: \(input)"
        completion(.success(result))
    }
}

AddCommand()
    .append(DoubleCommand())
    .append { (input) -> Result<Int> in
        // You can use a block as a command, with the signature defining the Input and Output
        let result = input * 3
        return .success(result)
    }
    .append(PrintCommand())
    .append { (result) in
        // You can also use a block with no return, which is handy as the completion
        print("I got the result: \"\(result)\"")
    }
    .execute((2, 3)) { (error) in
        // This is the ErrorHandler, which gets called if anything returns a failure
        print("oops: \(error)")
    }


