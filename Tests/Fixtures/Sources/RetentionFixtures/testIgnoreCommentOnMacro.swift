// periphery:ignore
@freestanding(expression)
public macro fixtureMacro3() -> Int = #externalMacro(module: "FixtureMacros", type: "FixtureMacro3")

@freestanding(expression)
public macro fixtureMacro4() -> Int = #externalMacro(module: "FixtureMacros", type: "FixtureMacro4")
