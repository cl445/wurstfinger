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
    budget_drift,
    Pattern,
    Term,
    _lint_rules,
    _pattern_carriers,
    _rule_id,
    load_glossary,
    mode_sync_lint,
    scan,
    strip_noncode,
    swift_files,
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

    def test_comment_inside_an_interpolation_is_blanked(self) -> None:
        self.assertEqual(_scan('let a = "\\(/* slotId */ value)"\n'), [])

    def test_nested_literal_inside_an_interpolation_is_blanked(self) -> None:
        self.assertEqual(_scan('let a = "\\(map["slotId"] ?? "")"\n'), [])

    def test_an_identifier_beside_a_nested_literal_still_counts(self) -> None:
        self.assertEqual(_scan('let a = "\\(map["x"] ?? slotId)"\n'), ["slotId"])

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


class LintRuleTests(unittest.TestCase):
    """The generated SwiftLint block, which CI lints with `--strict`."""

    def test_every_rejected_spelling_gets_a_rule(self) -> None:
        glossary = load_glossary()
        rules = _lint_rules(glossary)
        for term in glossary.terms:
            for alias in term.rejected:
                self.assertIn(f"glossary_{_rule_id(alias)}:", rules)
        for pattern in glossary.patterns:
            if pattern.checks_identifiers:
                self.assertIn(f"glossary_{pattern.id}:", rules)

    def test_pattern_exclusions_cover_the_aliases_it_also_matches(self) -> None:
        """SwiftLint has no alias/pattern dedup, so the exclusions must.

        `config_suffix` matches `LanguageConfig`, which a term already rejects,
        as well as spellings no term lists. If its exclusions only listed the
        files this script attributes to the pattern, `--strict` would fail in
        all 11 `LanguageConfig` files.
        """
        glossary = load_glossary()
        carriers = _pattern_carriers(glossary, swift_files())
        alias_files = {
            finding.path
            for finding in scan(glossary, swift_files())
            if finding.rejected == "LanguageConfig"
        }
        self.assertTrue(alias_files <= carriers["config_suffix"])

    def test_rules_are_indented_for_the_custom_rules_block(self) -> None:
        for line in _lint_rules(load_glossary()).splitlines():
            self.assertTrue(line.startswith("  "), line)

    def test_the_checked_in_block_is_current(self) -> None:
        self.assertEqual(mode_sync_lint(load_glossary(), check_only=True), 0)


class GlossaryFileTests(unittest.TestCase):
    """The checked-in glossary has to be internally consistent."""

    def test_repository_glossary_loads(self) -> None:
        glossary = load_glossary()
        self.assertTrue(glossary.terms)
        self.assertTrue(glossary.patterns)

    def test_every_term_has_a_definition(self) -> None:
        for term in load_glossary().terms:
            self.assertTrue(term.definition, f"{term.name} has no definition")


class BudgetDriftTests(unittest.TestCase):
    """A recorded budget and the tree it describes may not drift apart."""

    def test_matching_counts_are_clean(self) -> None:
        self.assertEqual(budget_drift({"a.swift": 3}, {"a.swift": 3}), ([], [], []))

    def test_a_count_above_its_budget_is_over(self) -> None:
        over, stale, slack = budget_drift({"a.swift": 4}, {"a.swift": 3})
        self.assertEqual((over, stale, slack), (["a.swift"], [], []))

    def test_a_file_absent_from_the_budget_is_over(self) -> None:
        over, _, _ = budget_drift({"new.swift": 1}, {})
        self.assertEqual(over, ["new.swift"])

    def test_a_budget_entry_with_nothing_left_is_stale(self) -> None:
        over, stale, slack = budget_drift({}, {"gone.swift": 2})
        self.assertEqual((over, stale, slack), ([], ["gone.swift"], []))

    def test_a_partial_shrink_is_slack(self) -> None:
        # The sequence this guards: 14 -> 13 without recording it leaves the
        # budget holding a slot, and the next rejected name takes it back to
        # 14 without ever exceeding the recorded number.
        over, stale, slack = budget_drift({"a.swift": 13}, {"a.swift": 14})
        self.assertEqual((over, stale, slack), ([], [], ["a.swift"]))

    def test_a_name_returning_into_unrecorded_slack_would_pass_unnoticed(self) -> None:
        # Same file, after the slack was recorded: the slot is gone, so the
        # returning name is over budget rather than free.
        self.assertEqual(budget_drift({"a.swift": 14}, {"a.swift": 13})[0], ["a.swift"])


if __name__ == "__main__":
    unittest.main()
