import SwiftUI
import WidgetKit

// ponytail: static content, no timeline data; share state through an app group when the face needs live status.
struct Entry: TimelineEntry { let date = Date() }

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry { Entry() }
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) { completion(Entry()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        completion(Timeline(entries: [Entry()], policy: .never))
    }
}

struct ComplicationView: View {
    @Environment(\.widgetFamily) private var family
    var body: some View {
        Group {
            switch family {
            case .accessoryCorner:
                Image(systemName: "mic.fill").font(.system(size: 22, weight: .bold))
                    .widgetLabel { Text("BB").font(.system(size: 14, weight: .black).width(.condensed)) }
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 0) {
                    Text("BB").font(.system(size: 13, weight: .black).width(.condensed)).tracking(1.2).widgetAccentable()
                    Text("Tap to record").font(.system(size: 18, weight: .black).width(.condensed)).minimumScaleFactor(0.7).lineLimit(1)
                }.frame(maxWidth: .infinity, alignment: .leading)
            case .accessoryInline:
                Text("BB · Record")
            default:
                ZStack {
                    Circle().fill(.black)
                    Image("BBLogo").resizable().scaledToFit().padding(8).widgetAccentable()
                }
            }
        }
        .widgetURL(URL(string: "bbwatch://record"))
        .containerBackground(.clear, for: .widget)
    }
}

struct BBComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BBRecord", provider: Provider()) { _ in ComplicationView() }
            .configurationDisplayName("BB")
            .description("Record a message for your agent.")
            .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct BBComplicationBundle: WidgetBundle {
    var body: some Widget { BBComplication() }
}
