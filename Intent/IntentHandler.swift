//
//  IntentHandler.swift
//  Intent
//
//  Created by Simon Hudishkin on 19.06.2022.
//

import Intents

class IntentHandler: INExtension, ConfigurationIntentHandling {

    func provideDataSourceTypeOptionsCollection(for intent: ConfigurationIntent, with completion: @escaping (INObjectCollection<DataSourceType>?, Error?) -> Void) {

        let items = MetricStore().metrics.values.map { DataSourceType(identifier: $0.id.uuidString, display: $0.title) }
        completion(INObjectCollection(items: items), nil)

    }


    override func handler(for intent: INIntent) -> Any {
        // This is the default implementation.  If you want different objects to handle different intents,
        // you can override this and return the handler you want for that particular intent.

        return self
    }

}
