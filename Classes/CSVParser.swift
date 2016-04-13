//
//  CSVParser.swift
//  kraftstoff
//
//  Created by Ingmar Stein on 06.05.15.
//
//

import Foundation

final class CSVParser {
	private var csvString: String

	private var separator: String! {
		didSet {
			let endTextMutableCharacterSet = NSCharacterSet.newline().mutableCopy() as! NSMutableCharacterSet
			endTextMutableCharacterSet.addCharacters(in: "\"")
			endTextMutableCharacterSet.addCharacters(in: separator.substring(to: separator.startIndex.successor()))
			endTextCharacterSet = endTextMutableCharacterSet
		}
	}
	private var scanner: NSScanner

	private var fieldNames = [String]()
	private var endTextCharacterSet = NSCharacterSet()

	static func simplifyCSVHeaderName(header: String) -> String {
		return header.replacingOccurrences(of: "[? :_\\-]+",
												with: "",
                                                 options: .regularExpressionSearch).uppercased()
	}

	init(inputCSVString: String) {
        // Convert DOS and legacy Mac line endings to Unix
		csvString = inputCSVString.replacingOccurrences(of: "\r\n?", with: "\n", options: .regularExpressionSearch)

        scanner = NSScanner(string:csvString)
        scanner.charactersToBeSkipped = nil
	}

	func revertToBeginning() {
		scanner.scanLocation = 0
	}

	private func numberOfNonEmtyFieldNames(array: [String]) -> Int {
		return array.reduce(0) { (count, name) in name.isEmpty ? count : count + 1 }
	}

	func parseTable() -> [CSVRecord]? {
		scannerLoop: while !scanner.isAtEnd {
			parseEmptyLines()

			let location = scanner.scanLocation

			for separatorString in [ ";", ",", "\t" ] {
				separator = separatorString
				scanner.scanLocation = location

				fieldNames = parseHeader() ?? []

				if fieldNames.count > 1 && parseLineSeparator() != nil {
					break scannerLoop
				}
			}

			skipLine()
		}

		if scanner.isAtEnd {
			return nil
		}

		var records = [CSVRecord]()

		if numberOfNonEmtyFieldNames(fieldNames) < 2 {
			return records
		}

		var record = parseRecord()

		if record == nil {
			return records
		}

		while record != nil {
			var keepGoing = true

			autoreleasepool {
				records.append(record!)

				if parseLineSeparator() == nil {
					keepGoing = false
				} else {
					record = parseRecord()
				}
			}

			if !keepGoing {
				break
			}
		}

		return records
	}

	private func parseHeader() -> [String]? {
		var name = parseField()

		if name == nil {
			return nil
		}

		var names = [String]()

		while name != nil {
			names.append(CSVParser.simplifyCSVHeaderName(name!))

			if parseSeparator() == nil {
				break
			}

			name = parseField()
		}

		return names
	}

	private func parseRecord() -> CSVRecord? {
		if parseEmptyLines() != nil {
			return nil
		}

		if scanner.isAtEnd {
			return nil
		}

		var field = parseField()

		if field == nil {
			return nil
		}

		var fieldNamesCount = fieldNames.count
		var fieldCount = 0

		var record = CSVRecord(minimumCapacity:fieldNamesCount)

		while field != nil {
			let fieldName: String

			if fieldNamesCount > fieldCount {
				fieldName = fieldNames[fieldCount]
			} else {
				fieldName = "FIELD_\(fieldCount + 1)"
				fieldNames.append(fieldName)
				fieldNamesCount += 1
			}

			record[fieldName] = field
			fieldCount += 1

			if parseSeparator() == nil {
				break
			}

			field = parseField()
		}

		return record
	}

	private func parseField() -> String? {
		scanner.scanCharacters(from: NSCharacterSet.whitespace(), into: nil)

		if let escapedString = parseEscaped() {
			return escapedString
		}

		if let nonEscapedString = parseNonEscaped() {
			return nonEscapedString
		}

		let currentLocation = scanner.scanLocation

		if parseSeparator() != nil || parseLineSeparator() != nil || scanner.isAtEnd {
			scanner.scanLocation = currentLocation
			return ""
		}

		return nil
	}

	private func parseEscaped() -> String? {
		if parseDoubleQuote() == nil {
			return nil
		}

		var accumulatedData = ""

		while true {
			var fragment = parseTextData()

			if fragment == nil {
				fragment = parseSeparator()

				if fragment == nil {
					fragment = parseLineSeparator()

					if fragment == nil {
						if parseTwoDoubleQuotes() != nil {
							fragment = "\""
						} else {
							break
						}
					}
				}
			}

			accumulatedData += fragment!
		}

		if parseDoubleQuote() == nil {
			return nil
		}

		return accumulatedData
	}

	private func parseNonEscaped() -> String? {
		return parseTextData()
	}

	private func parseTwoDoubleQuotes() -> String? {
		if scanner.scanString("\"\"", into: nil) {
			return "\"\""
		}

		return nil
	}

	private func parseDoubleQuote() -> String? {
		if scanner.scanString("\"", into: nil) {
			return "\""
		}

		return nil
	}

	private func parseSeparator() -> String? {
		if scanner.scanString(separator, into: nil) {
			return separator
		}

		return nil
	}

	private func parseEmptyLines() -> String? {
		var matchedNewlines: NSString?

		let location = scanner.scanLocation

		scanner.scanCharacters(from: NSCharacterSet.whitespace(), into: &matchedNewlines)

		if matchedNewlines == nil {
			scanner.scanCharacters(from: NSCharacterSet(charactersIn: ",;"), into: &matchedNewlines)
		}

		if matchedNewlines == nil {
			matchedNewlines = ""
		}

		if parseLineSeparator() == nil {
			scanner.scanLocation = location
			return nil
		}

		return matchedNewlines as? String
	}

	private func parseLineSeparator() -> String? {
		if scanner.scanString("\n", into: nil) {
			return "\n"
		}

		return nil
	}

	private func skipLine() -> String? {
		scanner.scanUpToCharacters(from: NSCharacterSet.newline(), into: nil)
		return parseLineSeparator()
	}

	private func parseTextData() -> String? {
		var data: NSString?
		scanner.scanUpToCharacters(from: endTextCharacterSet, into: &data)
		return data as? String
	}
}
