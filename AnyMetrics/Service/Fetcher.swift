//
//  Fetcher.swift
//  AnyMetrics
//
//  Created by Simon Hudishkin on 13.06.2022.
//

import Combine
import Foundation

let DEFAULT_TIMEOUT: Double = 30
let MAX_VALUE_LENGTH = 5


enum FetcherError: Error {
    case error, invalidData
}

enum FetcherResult {
    case result(ParseResult)
    case error(Error)
    case none
}

enum Fetcher {

    static func fetch(for url: URL, method: String, headers: [String:String], timeout: Double, completion: @escaping (Data?, Error?)-> Void) {
        var request = URLRequest(url: url)
        for (k,v) in headers {
            request.setValue(v, forHTTPHeaderField: k)
        }
        request.httpMethod = method
        request.timeoutInterval = timeout
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(nil, error)
                return
            }
            if let response = response as? HTTPURLResponse {
                if (200 ..< 300).contains(response.statusCode) {
                    return completion(data, nil)
                }
            }
            completion(nil, FetcherError.error)
        }
        task.resume()
    }

    static func fetch(for metric: Metric, completion: @escaping (FetcherResult)-> Void) {
        guard let requestData = metric.request else { return completion(.none) }

        fetch(
            for: requestData.url,
            method: requestData.method,
            headers: requestData.headers,
            timeout: metric.request?.timeout ?? DEFAULT_TIMEOUT) { (data, error) in
                if let error = error {
                    if metric.type == .checkStatus {
                        completion(.result(.status(false)))
                    } else {
                        completion(.error(error))
                    }
                    return
                }

                do {

                    let parser = MetricResponseParser(
                        type: metric.type,
                        formatter: metric.formatter ?? .default,
                        rules: metric.rules ?? .default)
                    let result = try parser.parse(data)
                    completion(.result(result))

                } catch {
                    completion(.error(error))
                }

            }
    }
    
    static func fetch(for url: URL, method: String, headers: [String:String], timeout: Double) -> Future<Data, Error> {
        return Future { promise in
            fetch(for: url, method: method, headers: headers, timeout: timeout) { data, error in
                if let error = error {
                    return promise(.failure(error))
                }
                if let data = data {
                    return promise(.success(data))
                }
                promise(.failure(FetcherError.error))

            }
        }
    }

    static func fetch(
        for url: URL,
        method: String,
        headers: [String:String],
        timeout: Double,
        responseType: TypeMetric,
        rules: ParseRules,
        formatter: MetricValueFormatter
    ) -> Future<FetcherResult, Never> {

        return Future { promise in
            fetch(for: url, method: method, headers: headers, timeout: timeout) { data, error in
                if let error = error {
                    return promise(.success(.error(error)))
                }

                guard let data = data else {
                    promise(.success(.error(FetcherError.invalidData)))
                    return
                }

                do {

                    let parser = MetricResponseParser(
                        type: responseType,
                        formatter: formatter,
                        rules: rules)
                    let result = try parser.parse(data)

                    promise(.success(.result(result)))

                } catch {
                    promise(.success(.error(error)))
                }


            }
        }
    }

    static func updateMetric(metric: Metric, completion: @escaping (Metric)-> Void) {
        var newMetric = metric
        Self.fetch(for: metric) { result in
            switch result {
            case .result(let value):
                switch value {
                case .status(let success):
                    newMetric.resultWithError = !success
                    newMetric.result = ""
                case .value(let valueString):
                    newMetric.result = valueString
                }
            case .error(_):
                newMetric.resultWithError = true
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
}
