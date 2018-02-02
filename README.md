# ChainableCommands

This is a library for chaining together commands, such that the output of each command flows into the command in the chain.

## Motivation

Sometimes, to achieve some outcome, you need to perform many different steps. Often you want to do them one at a time, and if there is an error you want to stop processing and capture it. And frequently the result of one step is needed by the following step.

How would you approach this problem? You could use `Operation` and `OperationQueue`, but that doesn't provide any good way to perform overall error-handling, or to take the result of one Operation and use it in the next.

You could have each step take a completion handler, and in there set up the next step. But if you have more than a few steps, you are quickly facing the [Pyramid Of Doom](https://en.wikipedia.org/wiki/Pyramid_of_doom_(programming)). Also, are you sure you remembered to call the error handler at every possible failure point?

## Approach

This library defines a `ChainableCommand` protocol which describes a "command". Every command has a specified `Input` and `Output` type. Commands may be chained together (using `append()`), as long as the new command has an input type that matches the output type of the command you are appending it to. And finally, a chain of commands can be executed.

## Example

Imagine that you have an image saved on disk. You'd like to read the image, transform it somehow, and then send it to a web service. The commands might look like this:

```swift
/// Takes a filename as input and outputs the contents as `Data`.
final class ReadFileCommand: ChainableCommand {
    typealias Input = String
    typealias Output = Data

    var continuation: Continuation<Output>?

    func main(_ input: String, completion: @escaping (Result<Data>) -> ()) {
        let filename = input
        // some code to read in the file ...
        <#code#>
        completion(.success(data))
    }
}

final class TransformImageDataCommand: ChainableCommand {
    typealias Input = Data
    typealias Output = Data

    var continuation: Continuation<Output>?

    func main(_ input: Data, completion: @escaping (Result<Data>) -> ()) {
        let originalData = input
        // some code to transform the data ...
        <#code#>
        completion(.success(transformedData))
    }
}

final class UploadImageDataCommand: ChainableCommand {
    typealias Input = Data
    typealias Output = Int

    var continuation: Continuation<Output>?

    func main(_ input: Data, completion: @escaping (Result<Int>) -> ()) {
        let data = input
        // some code to upload the data ...
        <#code#>
        completion(.success(httpResponse.statusCode))
    }
}
```

Then you can just string the commands together and execute them:
```swift
ReadFileCommand()
    .append(TransformImageDataCommand())
    .append(UploadImageDataCommand())
    .append { (statusCode) in
        print("Upload succeeded with status code: \(statusCode)")

    }.execute("image.png") { (error) in
        print("Failed with error: \(error)")
    }
```

## Roadmap
This is an early iteration of this concept, and may change. The repo also contains a Playground, which you can use to try this out. I am planning to make it available as a CocoaPod.

Any feedback is welcome.
