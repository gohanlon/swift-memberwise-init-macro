import SwiftSyntax

/// Removes attributes from a syntax tree while maintaining their surrounding trivia.
public class AttributeRemover: SyntaxRewriter {
  let predicate: (AttributeSyntax) -> Bool

  var triviaToAttachToNextToken: Trivia = Trivia()

  /// Initializes an attribute remover with a given predicate to determine which attributes to remove.
  ///
  /// - Parameter predicate: A closure that determines whether a given `AttributeSyntax` should be removed.
  ///   If this closure returns `true` for an attribute, that attribute will be removed.
  public init(removingWhere predicate: @escaping (AttributeSyntax) -> Bool) {
    self.predicate = predicate
  }

  public override func visit(_ nodeList: AttributeListSyntax) -> AttributeListSyntax {
    var filteredAttributes: [AttributeListSyntax.Element] = []

    for node in nodeList {
      switch node {
      case .attribute(let attribute):
        guard self.predicate(attribute) else {
          filteredAttributes.append(.attribute(prependAndClearAccumulatedTrivia(to: attribute)))
          continue
        }

        var leadingTrivia = attribute.leadingTrivia

        // Don't leave behind an empty line when the attribute being removed is on its own line,
        // based on the following conditions:
        //  - Leading trivia ends with a newline followed by arbitrary number of spaces or tabs
        //  - All leading trivia pieces after the last newline are just whitespace, ensuring
        //    there are no comments or other non-whitespace characters on the same line
        //    preceding the attribute.
        //  - There is no trailing trivia and the next token has leading trivia.
        if let lastNewline = leadingTrivia.pieces.lastIndex(where: \.isNewline),
          leadingTrivia.pieces[lastNewline...].allSatisfy(\.isWhitespace),
          attribute.trailingTrivia.isEmpty,
          let nextToken = attribute.nextToken(viewMode: .sourceAccurate),
          !nextToken.leadingTrivia.isEmpty
        {
          leadingTrivia = Trivia(pieces: leadingTrivia.pieces[..<lastNewline])
        }

        // Drop any spaces or tabs from the trailing trivia because there’s no
        // more attribute they need to separate.
        let trailingTrivia = attribute.trailingTrivia.trimmingPrefix(while: \.isSpaceOrTab)
        self.triviaToAttachToNextToken += leadingTrivia + trailingTrivia

        // If the attribute is not separated from the previous attribute by trivia, as in
        // `@First@Second var x: Int` (yes, that's valid Swift), removing the `@Second`
        // attribute and dropping all its trivia would cause `@First` and `var` to join
        // without any trivia in between, which is invalid. In such cases, the trailing trivia
        // of the attribute is significant and must be retained.
        if self.triviaToAttachToNextToken.isEmpty,
          let previousToken = attribute.previousToken(viewMode: .sourceAccurate),
          previousToken.trailingTrivia.isEmpty
        {
          self.triviaToAttachToNextToken = attribute.trailingTrivia
        }

      case .ifConfigDecl(_):
        filteredAttributes.append(node)
      }
    }

    // Ensure that any horizontal whitespace trailing the attributes list is trimmed if the next
    // token starts a new line.
    if let nextToken = nodeList.nextToken(viewMode: .sourceAccurate),
      nextToken.leadingTrivia.startsWithNewline
    {
      if !self.triviaToAttachToNextToken.isEmpty {
        self.triviaToAttachToNextToken = self.triviaToAttachToNextToken.trimmingSuffix(
          while: \.isSpaceOrTab)
      } else if let lastAttribute = filteredAttributes.last {
        filteredAttributes[filteredAttributes.count - 1].trailingTrivia = lastAttribute
          .trailingTrivia.trimmingSuffix(while: \.isSpaceOrTab)
      }
    }
    return AttributeListSyntax(filteredAttributes)
  }

  public override func visit(_ token: TokenSyntax) -> TokenSyntax {
    return prependAndClearAccumulatedTrivia(to: token)
  }

  /// Prepends the accumulated trivia to the given node's leading trivia.
  ///
  /// To preserve correct formatting after attribute removal, this function reassigns
  /// significant trivia accumulated from removed attributes to the provided subsequent node.
  /// Once attached, the accumulated trivia is cleared.
  ///
  /// - Parameter node: The syntax node receiving the accumulated trivia.
  /// - Returns: The modified syntax node with the prepended trivia.
  private func prependAndClearAccumulatedTrivia<T: SyntaxProtocol>(to syntaxNode: T) -> T {
    defer { self.triviaToAttachToNextToken = Trivia() }
    return syntaxNode.with(
      \.leadingTrivia, self.triviaToAttachToNextToken + syntaxNode.leadingTrivia)
  }
}

extension Trivia {
  fileprivate func trimmingPrefix(
    while predicate: (TriviaPiece) -> Bool
  ) -> Trivia {
    Trivia(pieces: self.drop(while: predicate))
  }

  fileprivate func trimmingSuffix(
    while predicate: (TriviaPiece) -> Bool
  ) -> Trivia {
    Trivia(
      pieces: self[...]
        .reversed()
        .drop(while: predicate)
        .reversed()
    )
  }

  fileprivate var startsWithNewline: Bool {
    self.first?.isNewline ?? false
  }
}
