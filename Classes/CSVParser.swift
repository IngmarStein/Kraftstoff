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
			assert(separator.count == 1)
			endTextCharacterSet = CharacterSet.newlines.union(CharacterSet(charactersIn: "\"" + separator))
		}
	}
	private var scanner: Scanner

	private var fieldNames = [String]()
	private var endTextCharacterSet = CharacterSet()

	static func simplifyCSVHeaderName(_ header: String) -> String {
		return header.replacingOccurrences(of: "[? :_\\-]+",
		                                   with: "",
		                                   options: .regularExpression).uppercased()
	}

	init(inputCSVString: String) {
		// Convert DOS and legacy Mac line endings to Unix
		csvString = inputCSVString.replacingOccurrences(of: "\r\n?", with: "\n", options: .regularExpression)

		scanner = Scanner(string: csvString)
		scanner.charactersToBeSkipped = nil
	}

	func revertToBeginning() {
		scanner.currentIndex = scanner.string.startIndex
	}

	private func numberOfNonEmtyFieldNames(_ array: [String]) -> Int {
		return array.reduce(0) { (count, name) in name.isEmpty ? count : count + 1 }
	}

	func parseTable() -> [CSVRecord]? {
		scannerLoop: while !scanner.isAtEnd {
			parseEmptyLines()

			let location = scanner.currentIndex

			for separatorString in [ ";", ",", "\t" ] {
				separator = separatorString
				scanner.currentIndex = location

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

		var record = CSVRecord(minimumCapacity: fieldNamesCount)

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
		_ = scanner.scanCharacters(from: CharacterSet.whitespaces)

		if let escapedString = parseEscaped() {
			return escapedString
		}

		if let nonEscapedString = parseNonEscaped() {
			return nonEscapedString
		}

		let currentLocation = scanner.currentIndex

		if parseSeparator() != nil || parseLineSeparator() != nil || scanner.isAtEnd {
			scanner.currentIndex = currentLocation
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
		return scanner.scanString("\"\"")
	}

	private func parseDoubleQuote() -> String? {
		return scanner.scanString("\"")
	}

	private func parseSeparator() -> String? {
		return scanner.scanString(separator)
	}

	@discardableResult private func parseEmptyLines() -> String? {
		let location = scanner.currentIndex

		var matchedNewlines = scanner.scanCharacters(from: CharacterSet.whitespaces)

		if matchedNewlines == nil {
			matchedNewlines = scanner.scanCharacters(from: CharacterSet(charactersIn: ",;"))
		}

		if matchedNewlines == nil {
			matchedNewlines = ""
		}

		if parseLineSeparator() == nil {
			scanner.currentIndex = location
			return nil
		}

		return matchedNewlines as String?
	}

	private func parseLineSeparator() -> String? {
		return scanner.scanString("\n")
	}

	@discardableResult private func skipLine() -> String? {
		_ = scanner.scanUpToCharacters(from: CharacterSet.newlines)
		return parseLineSeparator()
	}

	private func parseTextData() -> String? {
		return scanner.scanUpToCharacters(from: endTextCharacterSet)
	}

}
