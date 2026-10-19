import Foundation
import ProbeCodec
let root: URL
if CommandLine.arguments.count == 2 { root = URL(fileURLWithPath: CommandLine.arguments[1]) }
else { root = FileManager.default.temporaryDirectory.appendingPathComponent("native-codec-" + UUID().uuidString) }
let report = try CodecFixtures.run(root: root)
for result in report.cases { print("\(result.name): \(result.outcome)") }
guard report.cases.filter({ $0.outcome == "measured-candidate" }).count == 6,
      report.cases.filter({ $0.outcome == "expected-hold-source-retained" }).count == 4,
      report.chronologicalBoundaryPassed == true else { throw NSError(domain: "NativeCodecFixtureFailed", code: 1) }
print("PASS native AAC-LC: six decoded candidates, four retained-source failure cases, chronological append marker")
