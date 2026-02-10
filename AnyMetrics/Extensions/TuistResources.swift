import SwiftUI
import AnyMetricsShared

enum AssetColor {
    static var addMetricTint: Color {
        #if WIDGET_EXTENSION
        WidgetExtensionAsset.addMetricTint.swiftUIColor
        #else
        AnyMetricsAsset.Assets.addMetricTint.swiftUIColor
        #endif
    }

    static var baseText: Color {
        #if WIDGET_EXTENSION
        WidgetExtensionAsset.baseText.swiftUIColor
        #else
        AnyMetricsAsset.Assets.baseText.swiftUIColor
        #endif
    }

    static var galleryItemBackground: Color {
        #if WIDGET_EXTENSION
        WidgetExtensionAsset.galleryItemBackground.swiftUIColor
        #else
        AnyMetricsAsset.Assets.galleryItemBackground.swiftUIColor
        #endif
    }

    static var metricParamBackground: Color {
        #if WIDGET_EXTENSION
        WidgetExtensionAsset.metricParamBackground.swiftUIColor
        #else
        AnyMetricsAsset.Assets.metricParamBackground.swiftUIColor
        #endif
    }

    static var metricText: Color {
        #if WIDGET_EXTENSION
        WidgetExtensionAsset.metricText.swiftUIColor
        #else
        AnyMetricsAsset.Assets.metricText.swiftUIColor
        #endif
    }

    static var red: Color {
        #if WIDGET_EXTENSION
        WidgetExtensionAsset.red.swiftUIColor
        #else
        AnyMetricsAsset.Assets.red.swiftUIColor
        #endif
    }

    static var secondaryText: Color {
        #if WIDGET_EXTENSION
        WidgetExtensionAsset.secondaryText.swiftUIColor
        #else
        AnyMetricsAsset.Assets.secondaryText.swiftUIColor
        #endif
    }
}

enum AssetImage {
    static var appIconInfo: Image {
        #if WIDGET_EXTENSION
        WidgetExtensionAsset.appIconInfo.swiftUIImage
        #else
        AnyMetricsAsset.Assets.appIconInfo.swiftUIImage
        #endif
    }

    static var minus: Image {
        #if WIDGET_EXTENSION
        WidgetExtensionAsset.minus.swiftUIImage
        #else
        AnyMetricsAsset.Assets.minus.swiftUIImage
        #endif
    }

    static var plus: Image {
        #if WIDGET_EXTENSION
        WidgetExtensionAsset.plus.swiftUIImage
        #else
        AnyMetricsAsset.Assets.plus.swiftUIImage
        #endif
    }

    static var request: Image {
        #if WIDGET_EXTENSION
        WidgetExtensionAsset.request.swiftUIImage
        #else
        AnyMetricsAsset.Assets.request.swiftUIImage
        #endif
    }
}

enum L10n {
    static func appName() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.appName
        #else
        AnyMetricsStrings.appName
        #endif
    }

    static func addmetricTitleDisplay() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Addmetric.titleDisplay
        #else
        AnyMetricsStrings.Addmetric.titleDisplay
        #endif
    }

    static func addmetricTitleNew() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Addmetric.titleNew
        #else
        AnyMetricsStrings.Addmetric.titleNew
        #endif
    }

    static func addmetricTitleRequest() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Addmetric.titleRequest
        #else
        AnyMetricsStrings.Addmetric.titleRequest
        #endif
    }

    static func addmetricTitleValue() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Addmetric.titleValue
        #else
        AnyMetricsStrings.Addmetric.titleValue
        #endif
    }

    static func addmetricButtonAdd() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Addmetric.Button.add
        #else
        AnyMetricsStrings.Addmetric.Button.add
        #endif
    }

    static func addmetricButtonAddHttpHeader() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Addmetric.Button.addHttpHeader
        #else
        AnyMetricsStrings.Addmetric.Button.addHttpHeader
        #endif
    }

    static func addmetricButtonMakeRequest() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Addmetric.Button.makeRequest
        #else
        AnyMetricsStrings.Addmetric.Button.makeRequest
        #endif
    }

    static func addmetricButtonNext() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Addmetric.Button.next
        #else
        AnyMetricsStrings.Addmetric.Button.next
        #endif
    }

    static func addmetricButtonSave() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Addmetric.Button.save
        #else
        AnyMetricsStrings.Addmetric.Button.save
        #endif
    }

    static func addmetricFieldCaseSensitive() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Addmetric.Field.caseSensitive
        #else
        AnyMetricsStrings.Addmetric.Field.caseSensitive
        #endif
    }

    static func addmetricFieldHtmlParseRulePlaceholder() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Addmetric.Field.htmlParseRulePlaceholder
        #else
        AnyMetricsStrings.Addmetric.Field.htmlParseRulePlaceholder
        #endif
    }

    static func addmetricFieldHttpMethod() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Addmetric.Field.httpMethod
        #else
        AnyMetricsStrings.Addmetric.Field.httpMethod
        #endif
    }

    static func addmetricFieldJsonParseRulePlaceholder() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Addmetric.Field.jsonParseRulePlaceholder
        #else
        AnyMetricsStrings.Addmetric.Field.jsonParseRulePlaceholder
        #endif
    }

    static func addmetricFieldMaxLength() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Addmetric.Field.maxLength
        #else
        AnyMetricsStrings.Addmetric.Field.maxLength
        #endif
    }

    static func addmetricFieldParamMeasure() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Addmetric.Field.paramMeasure
        #else
        AnyMetricsStrings.Addmetric.Field.paramMeasure
        #endif
    }

    static func addmetricFieldParamMeasurePlaceholder() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Addmetric.Field.paramMeasurePlaceholder
        #else
        AnyMetricsStrings.Addmetric.Field.paramMeasurePlaceholder
        #endif
    }

    static func addmetricFieldRuleTypeContainsDescription() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Addmetric.Field.ruleTypeContainsDescription
        #else
        AnyMetricsStrings.Addmetric.Field.ruleTypeContainsDescription
        #endif
    }

    static func addmetricFieldRuleTypeEqualDescription() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Addmetric.Field.ruleTypeEqualDescription
        #else
        AnyMetricsStrings.Addmetric.Field.ruleTypeEqualDescription
        #endif
    }

    static func addmetricFieldRuleTypePlaceholder() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Addmetric.Field.ruleTypePlaceholder
        #else
        AnyMetricsStrings.Addmetric.Field.ruleTypePlaceholder
        #endif
    }

    static func addmetricFieldTitle() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Addmetric.Field.title
        #else
        AnyMetricsStrings.Addmetric.Field.title
        #endif
    }

    static func addmetricFieldTitlePlaceholder() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Addmetric.Field.titlePlaceholder
        #else
        AnyMetricsStrings.Addmetric.Field.titlePlaceholder
        #endif
    }

    static func addmetricFieldTypeMetric() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Addmetric.Field.typeMetric
        #else
        AnyMetricsStrings.Addmetric.Field.typeMetric
        #endif
    }

    static func addmetricFieldTypeParseRuleTitle() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Addmetric.Field.typeParseRuleTitle
        #else
        AnyMetricsStrings.Addmetric.Field.typeParseRuleTitle
        #endif
    }

    static func addmetricFieldUrlPlaceholder() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Addmetric.Field.urlPlaceholder
        #else
        AnyMetricsStrings.Addmetric.Field.urlPlaceholder
        #endif
    }

    static func addmetricFieldValue() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Addmetric.Field.value
        #else
        AnyMetricsStrings.Addmetric.Field.value
        #endif
    }

    static func addmetricFieldValueType() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Addmetric.Field.valueType
        #else
        AnyMetricsStrings.Addmetric.Field.valueType
        #endif
    }

    static func addmetricSectionFormatSettings() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Addmetric.Section.formatSettings
        #else
        AnyMetricsStrings.Addmetric.Section.formatSettings
        #endif
    }

    static func addmetricSectionHttpHeaders() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Addmetric.Section.httpHeaders
        #else
        AnyMetricsStrings.Addmetric.Section.httpHeaders
        #endif
    }

    static func addmetricSectionRequestSettings() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Addmetric.Section.requestSettings
        #else
        AnyMetricsStrings.Addmetric.Section.requestSettings
        #endif
    }

    static func addmetricSectionResult() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Addmetric.Section.result
        #else
        AnyMetricsStrings.Addmetric.Section.result
        #endif
    }

    static func commonClose() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Common.close
        #else
        AnyMetricsStrings.Common.close
        #endif
    }

    static func commonError() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Common.error
        #else
        AnyMetricsStrings.Common.error
        #endif
    }

    static func commonFaq() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Common.faq
        #else
        AnyMetricsStrings.Common.faq
        #endif
    }

    static func commonOk() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Common.ok
        #else
        AnyMetricsStrings.Common.ok
        #endif
    }

    static func commonSave() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Common.save
        #else
        AnyMetricsStrings.Common.save
        #endif
    }

    static func galleryNoMetricMessage() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Gallery.noMetricMessage
        #else
        AnyMetricsStrings.Gallery.noMetricMessage
        #endif
    }

    static func galleryButtonSend() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Gallery.Button.send
        #else
        AnyMetricsStrings.Gallery.Button.send
        #endif
    }

    static func galleryTitle() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Gallery.title
        #else
        AnyMetricsStrings.Gallery.title
        #endif
    }

    static func galleryMessageSubject() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Gallery.Message.subject
        #else
        AnyMetricsStrings.Gallery.Message.subject
        #endif
    }

    static func httpheadersAddButton() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Httpheaders.Add.button
        #else
        AnyMetricsStrings.Httpheaders.Add.button
        #endif
    }

    static func httpheadersAddTitle() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Httpheaders.Add.title
        #else
        AnyMetricsStrings.Httpheaders.Add.title
        #endif
    }

    static func httpheadersEnterName() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Httpheaders.enterName
        #else
        AnyMetricsStrings.Httpheaders.enterName
        #endif
    }

    static func httpheadersEnterValue() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Httpheaders.enterValue
        #else
        AnyMetricsStrings.Httpheaders.enterValue
        #endif
    }

    static func httpheadersSelectFromList() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Httpheaders.selectFromList
        #else
        AnyMetricsStrings.Httpheaders.selectFromList
        #endif
    }

    static func httpheadersSelectTitle() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Httpheaders.Select.title
        #else
        AnyMetricsStrings.Httpheaders.Select.title
        #endif
    }

    static func httpheadersSelectValueTitle() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Httpheaders.Select.valueTitle
        #else
        AnyMetricsStrings.Httpheaders.Select.valueTitle
        #endif
    }

    static func httpheadersSelectValuesFromList() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Httpheaders.selectValuesFromList
        #else
        AnyMetricsStrings.Httpheaders.selectValuesFromList
        #endif
    }

    static func httpheadersValueInformation() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Httpheaders.valueInformation
        #else
        AnyMetricsStrings.Httpheaders.valueInformation
        #endif
    }

    static func infoGithubAppRepo() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Info.githubAppRepo
        #else
        AnyMetricsStrings.Info.githubAppRepo
        #endif
    }

    static func infoGithubGalleryRepo() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Info.githubGalleryRepo
        #else
        AnyMetricsStrings.Info.githubGalleryRepo
        #endif
    }

    static func infoMessage() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Info.message
        #else
        AnyMetricsStrings.Info.message
        #endif
    }

    static func infoRate() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Info.rate
        #else
        AnyMetricsStrings.Info.rate
        #endif
    }

    static func infoTitle() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Info.title
        #else
        AnyMetricsStrings.Info.title
        #endif
    }

    static func infoVersion(_ value: Any) -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Info.version(value)
        #else
        AnyMetricsStrings.Info.version(value)
        #endif
    }

    static func metricActionsConfirmDelete() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Metric.Actions.confirmDelete
        #else
        AnyMetricsStrings.Metric.Actions.confirmDelete
        #endif
    }

    static func metricActionsDelete() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Metric.Actions.delete
        #else
        AnyMetricsStrings.Metric.Actions.delete
        #endif
    }

    static func metricActionsEdit() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Metric.Actions.edit
        #else
        AnyMetricsStrings.Metric.Actions.edit
        #endif
    }

    static func metricActionsSure() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Metric.Actions.sure
        #else
        AnyMetricsStrings.Metric.Actions.sure
        #endif
    }

    static func metricActionsTitle(_ value: Any) -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Metric.Actions.title(value)
        #else
        AnyMetricsStrings.Metric.Actions.title(value)
        #endif
    }

    static func metricActionsUpdateValue() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Metric.Actions.updateValue
        #else
        AnyMetricsStrings.Metric.Actions.updateValue
        #endif
    }

    static func metricAddCustom() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Metric.Add.custom
        #else
        AnyMetricsStrings.Metric.Add.custom
        #endif
    }

    static func metricPlaceholder() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Metric.placeholder
        #else
        AnyMetricsStrings.Metric.placeholder
        #endif
    }

    static func metricValueBad() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Metric.Value.bad
        #else
        AnyMetricsStrings.Metric.Value.bad
        #endif
    }

    static func metricValueGood() -> String {
        #if WIDGET_EXTENSION
        WidgetExtensionStrings.Metric.Value.good
        #else
        AnyMetricsStrings.Metric.Value.good
        #endif
    }
}
