//
//  ComplicationController.swift
//  WatchApp Extension
//
//  Created by Nathan Racklyeft on 8/29/15.
//  Copyright © 2015 Nathan Racklyeft. All rights reserved.
//

import ClockKit
import WatchKit


final class ComplicationController: NSObject, CLKComplicationDataSource {
    
    // MARK: - Timeline Configuration
    
    func getSupportedTimeTravelDirections(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimeTravelDirections) -> Void) {
        handler([.backward])
    }
    
    func getTimelineStartDate(for complication: CLKComplication, withHandler handler: @escaping (Date?) -> Void) {
        if let date = ExtensionDelegate.shared().loopManager.activeContext?.glucoseDate {
            handler(date)
        } else {
            handler(nil)
        }
    }
    
    func getTimelineEndDate(for complication: CLKComplication, withHandler handler: @escaping (Date?) -> Void) {
        if let date = ExtensionDelegate.shared().loopManager.activeContext?.glucoseDate {
            handler(date)
        } else {
            handler(nil)
        }
    }
    
    func getPrivacyBehavior(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationPrivacyBehavior) -> Void) {
        handler(.hideOnLockScreen)
    }
    
    // MARK: - Timeline Population

    private let chartManager = ComplicationChartManager()

    private func updateChartManagerIfNeeded(completion: @escaping () -> Void) {
        guard
            #available(watchOSApplicationExtension 5.0, *),
            let activeComplications = CLKComplicationServer.sharedInstance().activeComplications,
            activeComplications.contains(where: { $0.family == .graphicRectangular })
        else {
            completion()
            return
        }

        ExtensionDelegate.shared().loopManager.generateChartData { chartData in
            self.chartManager.data = chartData
            completion()
        }
    }

    func makeChart() -> UIImage? {
        // c.f. https://developer.apple.com/design/human-interface-guidelines/watchos/icons-and-images/complication-images/
        let size: CGSize = {
            switch WKInterfaceDevice.current().screenBounds.width {
            case let x where x > 180:  // 44mm
                return CGSize(width: 171.0, height: 54.0)
            default: // 40mm
                return CGSize(width: 150.0, height: 47.0)
            }
        }()

        let scale = WKInterfaceDevice.current().screenScale
        return chartManager.renderChartImage(size: size, scale: scale)
    }

    func getCurrentTimelineEntry(for complication: CLKComplication, withHandler handler: (@escaping (CLKComplicationTimelineEntry?) -> Void)) {
        updateChartManagerIfNeeded(completion: {
            let entry: CLKComplicationTimelineEntry?

            if  let context = ExtensionDelegate.shared().loopManager.activeContext,
                let glucoseDate = context.glucoseDate,
                glucoseDate.timeIntervalSinceNow.minutes >= -15,
                let template = CLKComplicationTemplate.templateForFamily(complication.family, from: context, chartGenerator: self.makeChart)
            {
                switch complication.family {
                case .graphicRectangular:
                    break
                default:
                    template.tintColor = .tintColor
                }
                entry = CLKComplicationTimelineEntry(date: glucoseDate, complicationTemplate: template)
            } else {
                entry = nil
            }

            handler(entry)
        })
    }
    
    func getTimelineEntries(for complication: CLKComplication, before date: Date, limit: Int, withHandler handler: (@escaping ([CLKComplicationTimelineEntry]?) -> Void)) {
        // Call the handler with the timeline entries prior to the given date
        handler(nil)
    }
    
    func getTimelineEntries(for complication: CLKComplication, after date: Date, limit: Int, withHandler handler: (@escaping ([CLKComplicationTimelineEntry]?) -> Void)) {
        updateChartManagerIfNeeded {
            let entries: [CLKComplicationTimelineEntry]?

            if  let context = ExtensionDelegate.shared().loopManager.activeContext,
                let glucoseDate = context.glucoseDate,
                glucoseDate.timeIntervalSince(date) > 0,
                let template = CLKComplicationTemplate.templateForFamily(complication.family, from: context, chartGenerator: self.makeChart)
            {
                template.tintColor = UIColor.tintColor
                entries = [CLKComplicationTimelineEntry(date: glucoseDate, complicationTemplate: template)]
            } else {
                entries = nil
            }

            handler(entries)
        }
    }

    // MARK: - Placeholder Templates

    func getLocalizableSampleTemplate(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTemplate?) -> Void) {
        let template = getLocalizableSampleTemplate(for: complication.family)
        handler(template)
    }

    func getLocalizableSampleTemplate(for family: CLKComplicationFamily) -> CLKComplicationTemplate? {
        let glucoseAndTrendText = CLKSimpleTextProvider.localizableTextProvider(withStringsFileTextKey: "120↘︎")
        let glucoseText = CLKSimpleTextProvider.localizableTextProvider(withStringsFileTextKey: "120")
        let timeText = CLKSimpleTextProvider.localizableTextProvider(withStringsFileTextKey: "3MIN")

        switch family {
        case .modularSmall:
            let template = CLKComplicationTemplateModularSmallStackText()
            template.line1TextProvider = glucoseAndTrendText
            template.line2TextProvider = timeText
            return template
        case .modularLarge:
            let template = CLKComplicationTemplateModularLargeTallBody()
            template.bodyTextProvider = glucoseAndTrendText
            template.headerTextProvider = timeText
            return template
        case .circularSmall:
            let template = CLKComplicationTemplateCircularSmallSimpleText()
            template.textProvider = glucoseAndTrendText
            return template
        case .extraLarge:
            let template = CLKComplicationTemplateExtraLargeStackText()
            template.line1TextProvider = glucoseAndTrendText
            template.line2TextProvider = timeText
            return template
        case .utilitarianSmall, .utilitarianSmallFlat:
            let template = CLKComplicationTemplateUtilitarianSmallFlat()
            template.textProvider = glucoseAndTrendText
            return template
        case .utilitarianLarge:
            let template = CLKComplicationTemplateUtilitarianLargeFlat()
            let eventualGlucoseText = CLKSimpleTextProvider.localizableTextProvider(withStringsFileTextKey: "75")
            template.textProvider = CLKSimpleTextProvider.localizableTextProvider(withStringsFileFormatKey: "UtilitarianLargeFlat", textProviders: [glucoseAndTrendText, eventualGlucoseText, CLKTimeTextProvider(date: Date())])
            return template
        case .graphicCorner:
            if #available(watchOSApplicationExtension 5.0, *) {
                let template = CLKComplicationTemplateGraphicCornerStackText()
                timeText.tintColor = .tintColor
                template.innerTextProvider = timeText
                template.outerTextProvider = glucoseAndTrendText
                return template
            } else {
                return nil
            }
        case .graphicCircular:
            if #available(watchOSApplicationExtension 5.0, *) {
                let template = CLKComplicationTemplateGraphicCircularOpenGaugeSimpleText()
                template.centerTextProvider = glucoseText
                template.bottomTextProvider = CLKSimpleTextProvider(text: "↘︎")
                template.gaugeProvider = CLKSimpleGaugeProvider(style: .fill, gaugeColor: .tintColor, fillFraction: 1)
                return template
            } else {
                return nil
            }
        case .graphicBezel:
            if #available(watchOSApplicationExtension 5.0, *) {
                let template = CLKComplicationTemplateGraphicBezelCircularText()
                guard let circularTemplate = getLocalizableSampleTemplate(for: .graphicCircular) as? CLKComplicationTemplateGraphicCircular else {
                    fatalError("\(#function) invoked with .graphicCircular must return a subclass of CLKComplicationTemplateGraphicCircular")
                }
                template.circularTemplate = circularTemplate
                template.textProvider = timeText
                return template
            } else {
                return nil
            }
        case .graphicRectangular:
            if #available(watchOSApplicationExtension 5.0, *) {
                let template = CLKComplicationTemplateGraphicRectangularLargeImage()
                // TODO: Better placeholder image here
                template.imageProvider = CLKFullColorImageProvider(fullColorImage: UIImage())
                template.textProvider = glucoseAndTrendText
                return template
            } else {
                return nil
            }
        @unknown default:
            fatalError()
        }
    }
}
