//===----------------------------------------------------------------------===//
//
// AttributeRemover is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import SwiftSyntax

/// Removes attributes from a syntax tree while maintaining their surrounding trivia.
class AttributeRemover509: SyntaxRewriter {
  let predicate: (AttributeSyntax) -> Bool

  var triviaToAttachToNextToken: Trivia = Trivia()

  init(removingWhere predicate: @escaping (AttributeSyntax) -> Bool) {
    self.predicate = predicate
  }

  override func visit(_ node: AttributeListSyntax) -> AttributeListSyntax {
    var filteredAttributes: [AttributeListSyntax.Element] = []
    for case .attribute(let attribute) in node {
      if self.predicate(attribute) {
        var leadingTrivia = node.leadingTrivia
        if let lastNewline = leadingTrivia.pieces.lastIndex(where: { $0.isNewline }),
          leadingTrivia.pieces[lastNewline...].allSatisfy(\.isWhitespace),
          node.trailingTrivia.isEmpty,
          node.nextToken(viewMode: .sourceAccurate)?.leadingTrivia.first?.isNewline ?? false
        {
          // If the attribute is on its own line based on the following conditions,
          // remove the newline from it so we don’t end up with an empty line
          //  - Trailing trivia ends with a newline followed by arbitrary number of spaces or tabs
          //  - There is no trailing trivia and the next token starts on a new line
          leadingTrivia = Trivia(pieces: leadingTrivia.pieces[..<lastNewline])
        }
        // Drop any spaces or tabs from the trailing trivia because there’s no
        // more attribute they need to separate.
        let trailingTrivia = Trivia(
          pieces: attribute.trailingTrivia.drop(while: { $0.isSpaceOrTab }))
        triviaToAttachToNextToken += leadingTrivia + trailingTrivia
      } else {
        filteredAttributes.append(.attribute(attribute))
      }
    }
    return AttributeListSyntax(filteredAttributes)
  }

  override func visit(_ token: TokenSyntax) -> TokenSyntax {
    if !triviaToAttachToNextToken.isEmpty {
      defer { triviaToAttachToNextToken = Trivia() }
      return token.with(\.leadingTrivia, triviaToAttachToNextToken + token.leadingTrivia)
    } else {
      return token
    }
  }
}
