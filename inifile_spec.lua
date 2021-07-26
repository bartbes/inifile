local inifile = require "inifile"

local function parse(text)
	return inifile.parse(text, "memory")
end

local function save(data)
	return inifile.save("dummy", data, "memory")
end

describe("Parsing", function()
	it("returns data per section", function()
		local data = parse[==[
[Test1]
Some=Data

[Test2]
Some=Other data
]==]

		assert.are.equal("Data", data.Test1.Some)
		assert.are.equal("Other data", data.Test2.Some)
	end)

	it("detects numbers", function()
		local data = parse[==[
[Test]
Value1=3.14
]==]

		assert.are.equal(3.14, data.Test.Value1)
		assert.are.equal("number", type(data.Test.Value1))
	end)

	it("detects booleans", function()
		local data = parse[==[
[Test]
Value1=true
Value2=false
]==]

		assert.is_true(data.Test.Value1)
		assert.are.equal("boolean", type(data.Test.Value1))
		assert.is_false(data.Test.Value2)
		assert.are.equal("boolean", type(data.Test.Value2))
	end)

	it("handles values with = signs", function()
		local data = parse[==[
[Test]
Value=some=data
]==]

		assert.are.equal("some=data", data.Test.Value)
	end)

	it("supports reopening sections", function()
		local data = parse[==[
[Test1]
A=1

[Test2]
A=2
B=2

[Test1]
B=3
]==]

		assert.are.equal(1, data.Test1.A)
		assert.are.equal(2, data.Test2.A)
		assert.are.equal(2, data.Test2.B)
		assert.are.equal(3, data.Test1.B)
	end)

	it("returns no extra data", function()
		local data = parse[==[
[Test]
Some=data
Other=data
]==]

		assert.are.equal("data", data.Test.Some)
		assert.are.equal("data", data.Test.Other)

		for section in pairs(data) do
			assert.are.equal("Test", section)
		end

		for key in pairs(data.Test) do
			assert.is_true(key == "Some" or key == "Other")
		end
	end)

	it("ignores comments", function()
		local data = parse[==[
; Comment outside of section
[Test]
; Comment at start of section
Some=data
; Comment in middle of section
Other=data
; Comment at the end
]==]

		assert.are.equal("data", data.Test.Some)
		assert.are.equal("data", data.Test.Other)

		for section in pairs(data) do
			assert.are.equal("Test", section)
		end

		for key in pairs(data.Test) do
			assert.is_true(key == "Some" or key == "Other")
		end
	end)
end)

describe("Saving", function()
	it("writes all data types", function()
		local toStringable = setmetatable({}, {
			__tostring = function()
				return "using __tostring"
			end
		})

		local randomTable = {}

		local ini = save{
			Test = {
				string = "abc",
				number = 1.23,
				boolean = true,
				toStringable = toStringable,
				randomTable = randomTable,
			}
		}

		local expected_lines = {
			"string=abc",
			"number=1.23",
			"boolean=true",
			"toStringable=using __tostring",
			"randomTable=" .. tostring(randomTable)
		}

		-- Skip header
		ini = ini:match("^.-\n(.+)$")

		-- Parse all lines into a table
		local ini_lines = {}
		for line in ini:gmatch("(.-)\n") do
			table.insert(ini_lines, line)
		end

		-- Sort both, for equality
		table.sort(expected_lines)
		table.sort(ini_lines)
		assert.are.same(expected_lines, ini_lines)
	end)
end)

describe("Formatting", function()
	describe("preserves order and comments", function()
		it("without modifications", function()
			local input = [==[
; Comment outside of section

[Section1]
; Comment in section
Some=Value

[Section2]
Some=Other value
Second=value
]==]

			local output = save(parse(input))
			assert.are.equal(input, output)
		end)

		it("moving comments to the start of a section", function()
			local input = [==[
[Section]
; Comment at start
Some=Value
; Comment in middle
Other=Value
; Comment at end
]==]

			local expected = [==[
[Section]
; Comment at start
; Comment in middle
; Comment at end
Some=Value
Other=Value
]==]

			local output = save(parse(input))
			assert.are.equal(expected, output)
		end)

		it("skipping removed values", function()
			local input = [==[
[Section]
D=1
C=2
B=3
A=4
]==]

			local expected = [==[
[Section]
D=1
C=2
A=4
]==]

			local parsed = parse(input)
			parsed.Section.B = nil
			local output = save(parsed)
			assert.are.equal(expected, output)
		end)

		it("skipping removed sections", function()
			local input = [==[
[D]
Value=1

[C]
Value=2

[B]
Value=3

[A]
Value=4
]==]

			local expected = [==[
[D]
Value=1

[C]
Value=2

[A]
Value=4
]==]

			local parsed = parse(input)
			parsed.B = nil
			local output = save(parsed)
			assert.are.equal(expected, output)
		end)

		it("appending added values", function()
			local input = [==[
[Section]
A=1
C=3
D=4
]==]

			local expected = [==[
[Section]
A=1
C=3
D=4
B=2
]==]

			local parsed = parse(input)
			parsed.Section.B = 2
			local output = save(parsed)
			assert.are.equal(expected, output)
		end)

		it("appending added sections", function()
			local input = [==[
[D]
Value=1

[C]
Value=2

[A]
Value=4
]==]

			local expected = [==[
[D]
Value=1

[C]
Value=2

[A]
Value=4

[B]
Value=3
]==]

			local parsed = parse(input)
			parsed.B = { Value = 3 }
			local output = save(parsed)
			assert.are.equal(expected, output)
		end)
	end)
end)
