import XCTest
@testable import RingKnot

final class DirectionAndCellTests: XCTestCase {
    func testAllEightDirectionsParse() {
        let raws = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        for raw in raws {
            XCTAssertNotNil(Direction.parse(raw), "failed to parse \(raw)")
        }
        XCTAssertEqual(Direction.parse("n"), .n)
        XCTAssertNil(Direction.parse("X"))
        XCTAssertNil(Direction.parse(""))
    }

    func testDirectionVectorsMatchSpec() {
        XCTAssertEqual(Direction.n.vector.dx, 0); XCTAssertEqual(Direction.n.vector.dy, -1)
        XCTAssertEqual(Direction.ne.vector.dx, 1); XCTAssertEqual(Direction.ne.vector.dy, -1)
        XCTAssertEqual(Direction.e.vector.dx, 1); XCTAssertEqual(Direction.e.vector.dy, 0)
        XCTAssertEqual(Direction.se.vector.dx, 1); XCTAssertEqual(Direction.se.vector.dy, 1)
        XCTAssertEqual(Direction.s.vector.dx, 0); XCTAssertEqual(Direction.s.vector.dy, 1)
        XCTAssertEqual(Direction.sw.vector.dx, -1); XCTAssertEqual(Direction.sw.vector.dy, 1)
        XCTAssertEqual(Direction.w.vector.dx, -1); XCTAssertEqual(Direction.w.vector.dy, 0)
        XCTAssertEqual(Direction.nw.vector.dx, -1); XCTAssertEqual(Direction.nw.vector.dy, -1)
    }

    func testCellParsing() {
        XCTAssertEqual(Cell.parse("A1"), Cell(row: 0, col: 0))
        XCTAssertEqual(Cell.parse("B3"), Cell(row: 1, col: 2))
        XCTAssertEqual(Cell.parse("F6"), Cell(row: 5, col: 5))
        XCTAssertEqual(Cell.parse("C3a"), Cell(row: 2, col: 2, subSlot: 1))
        XCTAssertEqual(Cell.parse("C3b"), Cell(row: 2, col: 2, subSlot: 2))
        XCTAssertEqual(Cell.parse("C3c"), Cell(row: 2, col: 2, subSlot: 3))
        XCTAssertNil(Cell.parse(""))
        XCTAssertNil(Cell.parse("3A"))
        XCTAssertNil(Cell.parse("A"))
        XCTAssertNil(Cell.parse("A0"))
        XCTAssertNil(Cell.parse("C3z"))
    }

    func testCellRoundTrip() {
        let inputs = ["A1", "B3", "F6", "C3a", "C3b", "D4a"]
        for raw in inputs {
            let cell = Cell.parse(raw)
            XCTAssertEqual(cell?.description, raw, "round-trip failed for \(raw)")
        }
    }
}
