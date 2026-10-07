@freestanding(expression)
public macro fixtureMacro1() -> Int = #externalMacro(module: "FixtureMacros", type: "FixtureMacro1")

@freestanding(expression)
macro fixtureMacro2() -> Int = #externalMacro(module: "FixtureMacros", type: "FixtureMacro2")
