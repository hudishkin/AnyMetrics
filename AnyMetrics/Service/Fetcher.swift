//
//  Fetcher.swift
//  AnyMetrics
//
//  Created by Simon Hudishkin on 13.06.2022.
//

import Combine
import Foundation
import SwiftyJSON

let DEFAULT_TIMEOUT: Double = 30
let MAX_VALUE_LENGTH = 5


enum FetcherError: Error {
    case error, invalidData
}

enum FetcherResult {
    case value(String)
    case check(Bool)
    case error(Error)
    case none
}

enum Fetcher {

    static func fetch(for metric: Metric, completion: @escaping (FetcherResult)-> Void) {
        if let requestData = metric.request {
            var request = URLRequest(url: requestData.url)
            for (k,v) in requestData.headers {
                request.setValue(v, forHTTPHeaderField: k)
            }
            request.httpMethod = requestData.method
            request.timeoutInterval = metric.request?.timeout ?? DEFAULT_TIMEOUT
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    completion(.error(error))
                    return
                }
                if let response = response as? HTTPURLResponse {
                    if (200 ..< 300).contains(response.statusCode) {
                        if metric.type == .json {
                            let result = self.getValueFromJSON(data, rules: metric.parseRules, formatter: metric.formatter)
                            completion(.value(result))
                        }
                        if metric.type == .checker {
                            completion(.check(true))
                        }
                        return
                    }
                }
                if metric.type == .checker {
                    completion(.check(false))
                    return
                }
                completion(FetcherResult.none)
            }
            task.resume()
        } else {
            completion(.none)
        }
    }

    static func updateMetric(metric: Metric, completion: @escaping (Metric)-> Void) {
        var newMetric = metric
        Self.fetch(for: metric) { result in
            switch result {
            case .check(let success):
                newMetric.hasError = !success
                newMetric.lastValue = ""
            case .value(let value):
                newMetric.lastValue = value
            case .error(_):
                newMetric.hasError = true
            case .none:
                break
            }
            completion(newMetric)
        }
    }

    static func fetch(for metric: Metric)-> Future<FetcherResult, Never> {
        return Future { promise in
            Self.fetch(for: metric) { result in
                promise(Result.success(result))
            }
        }
    }

    static private func getValueFromJSON(
        _ data: Data?,
        rules: String?,
        formatter: MetricFormatter?) -> String {
            
        guard let data = data else { return "" }
        if let json = try? JSON(data: data), let rules = rules {
            return json.parseValue(by: rules, formatter: formatter) ?? ""
        }
        return String(data: data, encoding: .utf8)!
    }
}
