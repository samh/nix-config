"""Regression checks for diagnostic evidence handling; no network access."""
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location(
    "network_monitor", Path(__file__).with_name("network-monitor.py")
)
monitor = importlib.util.module_from_spec(spec)
spec.loader.exec_module(monitor)


def sample(second, status, name="icmp-cloudflare"):
    return dict(name=name, finished=f"2026-10-29T13:00:{second:02d}-04:00", status=status)


class EvidenceTests(unittest.TestCase):
    def test_success_ends_failure_window(self):
        rows = [sample(0, "FAIL"), sample(5, "OK"), sample(10, "FAIL")]
        windows = monitor.failure_windows(rows, 15)
        self.assertEqual(len(windows), 2)
        self.assertTrue(all(start == end for _, start, end in windows))

    def test_probe_error_ends_failure_window(self):
        rows = [sample(0, "FAIL"), sample(5, "ERROR"), sample(10, "FAIL")]
        self.assertEqual(len(monitor.failure_windows(rows, 15)), 2)
        self.assertEqual(monitor.failure_windows([sample(0, "ERROR")], 15), [])

    def test_gap_does_not_imply_continuous_outage(self):
        rows = [sample(0, "FAIL"), sample(30, "FAIL")]
        self.assertEqual(len(monitor.failure_windows(rows, 15)), 2)

    def test_samples_are_ordered_independently_per_probe(self):
        rows = [sample(10, "FAIL"), sample(5, "OK", "icmp-router"),
                sample(0, "FAIL")]
        windows = monitor.failure_windows(rows, 15)
        self.assertEqual(len(windows), 1)
        self.assertEqual((windows[0][2] - windows[0][1]).total_seconds(), 10)

    def test_public_failure_does_not_exonerate_local_path(self):
        for tiers in ({"wan"}, {"app"}):
            _, explanation = monitor.verdict(tiers)
            for possible_cause in ("OPNsense", "gateway", "ISP", "target"):
                self.assertIn(possible_cause, explanation)

    def test_mixed_failures_do_not_claim_both_dns_paths_failed(self):
        _, explanation = monitor.verdict({"dns-lan", "app"})
        self.assertIn("before attributing", explanation)

    def test_dns_response_status_matters_even_when_dig_exits_zero(self):
        for status, answers in (("SERVFAIL", 0), ("REFUSED", 0), ("NOERROR", 0)):
            self.assertEqual(monitor.classify(
                "dns", 0, f"status: {status}, ANSWER: {answers}"
            ), "FAIL")
        self.assertEqual(monitor.classify("dns", 0, "status: NOERROR, ANSWER: 1"), "OK")


if __name__ == "__main__":
    unittest.main()
