import Foundation
import Testing
@testable import KiroChatViewer

// MARK: - PerformanceMonitor Tests

@Suite struct PerformanceMonitorTests {

    @Test func recordStoresMetric() {
        let monitor = PerformanceMonitor()
        monitor.record("load", "42ms")
        #expect(monitor.metrics["load"] == "42ms")
    }

    @Test func recordOverwritesPrevious() {
        let monitor = PerformanceMonitor()
        monitor.record("load", "42ms")
        monitor.record("load", "100ms")
        #expect(monitor.metrics["load"] == "100ms")
    }

    @Test func startAndEndProducesMetric() throws {
        let monitor = PerformanceMonitor()
        monitor.start("op")
        // Tiny sleep to ensure non-zero duration
        Thread.sleep(forTimeInterval: 0.01)
        monitor.end("op")
        let value = try #require(monitor.metrics["op"])
        #expect(value.hasSuffix("ms"))
    }

    @Test func endWithoutStartIsNoop() {
        let monitor = PerformanceMonitor()
        monitor.end("never-started")
        #expect(monitor.metrics["never-started"] == nil)
    }

    @Test func multipleTimersIndependent() {
        let monitor = PerformanceMonitor()
        monitor.start("a")
        monitor.start("b")
        monitor.end("a")
        #expect(monitor.metrics["a"] != nil)
        #expect(monitor.metrics["b"] == nil) // not ended yet
        monitor.end("b")
        #expect(monitor.metrics["b"] != nil)
    }

    @Test func metricsStartEmpty() {
        let monitor = PerformanceMonitor()
        #expect(monitor.metrics.isEmpty)
    }
}

// MARK: - MarkdownCache Tests

@Suite struct MarkdownCacheTests {

    @Test func getReturnsCachedContent() {
        let cache = MarkdownCache()
        let first = cache.get("k1", content: "hello")
        let second = cache.get("k1", content: "different")
        #expect(first == "hello")
        #expect(second == "hello") // returns cached, not new content
    }

    @Test func differentKeysStoreSeparately() {
        let cache = MarkdownCache()
        _ = cache.get("k1", content: "aaa")
        _ = cache.get("k2", content: "bbb")
        #expect(cache.get("k1", content: "x") == "aaa")
        #expect(cache.get("k2", content: "x") == "bbb")
    }

    @Test func clearRemovesAll() {
        let cache = MarkdownCache()
        _ = cache.get("k1", content: "aaa")
        cache.clear()
        // After clear, should store new content
        let result = cache.get("k1", content: "new")
        #expect(result == "new")
    }
}
