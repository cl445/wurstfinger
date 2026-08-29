#!/usr/bin/env python3
"""Tests for the naming checker.

The budget in `.naming-budget.json` is only as trustworthy as the counting, and
the counting is where this script can be quietly wrong: a rejected spelling
hidden in a comment must not count, one inside a string interpolation must.

    python3 -m unittest discover -s scripts -p 'test_*.py'
"""

from __future__ import annotations

from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))

from check_naming import (  # noqa: E402
    Glossary,
    Pattern,
    Term,
    load_glossary,
    scan,
    strip_noncode,
)


def _glossary() -> Glossary:
    """Return a small glossary: one alias, one pattern with an allow-list."""
    return Glossary(
        terms=(Term(name="keyId", zone="A", definition="", rejected=("slotId",), note=""),),
        patterns=(
            Pattern(
                id="layer_word",
                regex=r"\b[A-Za-z]*(?<![Pp])[Ll]ayer[A-Za-z]*\b",
                replacement="`mode`",
                rationale="",
                allowed=("CALayer", "layer"),
                applies_to=("identifier",),
            ),
        ),
        exceptions={},
        exception_reasons={},
    )


def _scan(source: str) -> list[str]:
    """Return the names found in `source`, written to a temporary file."""
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        file = root / "Sample.swift"
        file.write_text(source, encoding="utf-8")
        return [finding.name for finding in scan(_glossary(), [file], root=root)]


class StripNoncodeTests(unittest.TestCase):
    """What the matcher is allowed to see."""

    def test_line_comment_is_blanked(self) -> None:
        self.assertEqual(_scan("let a = 1 // slotId here\n"), [])

    def test_block_comment_is_blanked(self) -> None:
        self.assertEqual(_scan("/* slotId\n slotId */\nlet a = 1\n"), [])

    def test_nested_block_comment_is_blanked(self) -> None:
        self.assertEqual(_scan("/* outer /* slotId */ still slotId */\nlet a = 1\n"), [])

    def test_string_literal_is_blanked(self) -> None:
        self.assertEqual(_scan('let a = "slotId"\n'), [])

    def test_multiline_string_is_blanked(self) -> None:
        self.assertEqual(_scan('let a = """\nslotId\n"""\n'), [])

    def test_raw_string_is_blanked(self) -> None:
        self.assertEqual(_scan('let a = #"slotId \\(slotId)"#\n'), [])

    def test_escaped_quote_does_not_end_the_string(self) -> None:
        self.assertEqual(_scan('let a = "\\" slotId"\nlet b = 1\n'), [])

    def test_interpolation_is_kept(self) -> None:
        self.assertEqual(_scan('let a = "id: \\(slotId)"\n'), ["slotId"])

    def test_nested_interpolation_is_kept(self) -> None:
        self.assertEqual(_scan('let a = "\\(map[slotId] ?? "x")"\n'), ["slotId"])

    def test_line_numbers_survive_stripping(self) -> None:
        source = '// slotId\n/* two\nlines */\nlet a = slotId\n'
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            file = root / "Sample.swift"
            file.write_text(source, encoding="utf-8")
            findings = scan(_glossary(), [file], root=root)
        self.assertEqual([finding.line for finding in findings], [4])

    def test_stripping_preserves_length(self) -> None:
        source = 'let a = "x" // y\n/* z */\n'
        self.assertEqual(len(strip_noncode(source)), len(source))


class MatchingTests(unittest.TestCase):
    """Which identifiers a term and a pattern claim."""

    def test_alias_matches_whole_word_only(self) -> None:
        self.assertEqual(_scan("let slotIdentifier = 1\nlet mySlotId = 2\n"), [])

    def test_alias_matches_the_identifier(self) -> None:
        self.assertEqual(_scan("func f(slotId: String) { _ = slotId }\n"), ["slotId", "slotId"])

    def test_pattern_matches_a_compound(self) -> None:
        self.assertEqual(_scan("let forcedLayer = 1\n"), ["forcedLayer"])

    def test_pattern_allows_apple_api(self) -> None:
        self.assertEqual(_scan("view.layer.cornerRadius = 8\nlet l: CALayer? = nil\n"), [])

    def test_pattern_does_not_match_player(self) -> None:
        self.assertEqual(_scan("let hapticPlayer = HapticFeedbackPlayer()\n"), [])

    def test_pattern_does_not_double_count_an_alias(self) -> None:
        """A spelling a term already rejects is reported once, under the term."""
        glossary = Glossary(
            terms=(Term(name="keyId", zone="A", definition="", rejected=("slotId",), note=""),),
            patterns=(
                Pattern(
                    id="id_suffix",
                    regex=r"\b[a-z]+Id\b",
                    replacement="`keyId`",
                    rationale="",
                    allowed=(),
                    applies_to=("identifier",),
                ),
            ),
            exceptions={},
            exception_reasons={},
        )
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            file = root / "Sample.swift"
            file.write_text("let slotId = 1\n", encoding="utf-8")
            findings = scan(glossary, [file], root=root)
        self.assertEqual([finding.rejected for finding in findings], ["slotId"])


class GlossaryFileTests(unittest.TestCase):
    """The checked-in glossary has to be internally consistent."""

    def test_repository_glossary_loads(self) -> None:
        glossary = load_glossary()
        self.assertTrue(glossary.terms)
        self.assertTrue(glossary.patterns)

    def test_every_term_has_a_definition(self) -> None:
        for term in load_glossary().terms:
            self.assertTrue(term.definition, f"{term.name} has no definition")


if __name__ == "__main__":
    unittest.main()
