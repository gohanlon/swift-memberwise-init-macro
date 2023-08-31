import Foundation

extension String {
  var isValidSwiftLabel: Bool {
    let pattern = #"^[_a-zA-Z][_a-zA-Z0-9]*$"#
    let regex = try! NSRegularExpression(pattern: pattern)
    let range = NSRange(self.startIndex..<self.endIndex, in: self)
    return regex.firstMatch(in: self, options: [], range: range) != nil
  }
}

extension String {
  var isInvalidSwiftLabel: Bool {
    !self.isValidSwiftLabel
  }
}
