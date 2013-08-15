require "rubyXL"

workbook = RubyXL::Parser.parse("data/Book1.xlsx")
p workbook.worksheets[0]
