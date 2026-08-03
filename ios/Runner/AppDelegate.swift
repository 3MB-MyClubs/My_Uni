import Flutter
import EventKit
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let eventStore = EKEventStore()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()

    let weatherChannel = FlutterMethodChannel(
      name: "ku_app/native_weather",
      binaryMessenger: messenger
    )
    weatherChannel.setMethodCallHandler { call, result in
      if call.method == "openWeatherApp" {
        self.openWeatherApp(result: result)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    let calendarChannel = FlutterMethodChannel(
      name: "ku_app/apple_calendar",
      binaryMessenger: messenger
    )
    calendarChannel.setMethodCallHandler { call, result in
      if call.method == "syncEvents" {
        self.syncEventsToAppleCalendar(call: call, result: result)
      } else if call.method == "removeEvent" {
        self.removeEventFromAppleCalendar(call: call, result: result)
      } else if call.method == "checkPermission" {
        self.checkCalendarPermissionStatus(result: result)
      } else if call.method == "requestPermission" {
        self.requestCalendarAccess { granted in
          result(granted ? "authorized" : "denied")
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    let notificationChannel = FlutterMethodChannel(
      name: "ku_app/notifications",
      binaryMessenger: messenger
    )
    notificationChannel.setMethodCallHandler { call, result in
      if call.method == "removeDeliveredNotificationsForThreads" {
        self.removeDeliveredNotificationsForThreads(call: call, result: result)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func removeDeliveredNotificationsForThreads(
    call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    guard let args = call.arguments as? [String: Any],
          let threadIds = args["threadIds"] as? [String] else {
      result(FlutterError(code: "bad_args", message: "Missing thread identifiers", details: nil))
      return
    }

    let requestedThreads = Set(threadIds)
    let center = UNUserNotificationCenter.current()
    center.getDeliveredNotifications { notifications in
      let identifiers = notifications.compactMap { notification in
        requestedThreads.contains(notification.request.content.threadIdentifier)
          ? notification.request.identifier
          : nil
      }
      center.removeDeliveredNotifications(withIdentifiers: identifiers)
      DispatchQueue.main.async {
        result(identifiers.count)
      }
    }
  }

  private func openWeatherApp(result: @escaping FlutterResult) {
    guard let url = URL(string: "weather://") else {
      result(false)
      return
    }

    if UIApplication.shared.canOpenURL(url) {
      UIApplication.shared.open(url) { opened in
        result(opened)
      }
    } else {
      result(false)
    }
  }

  private func syncEventsToAppleCalendar(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let eventPayloads = args["events"] as? [[String: Any]] else {
      result(FlutterError(code: "bad_args", message: "Missing events", details: nil))
      return
    }

    requestCalendarAccess { granted in
      guard granted else {
        result([])
        return
      }

      do {
        let calendar = try self.unihubCalendar()
        var syncedIds: [String] = []

        for payload in eventPayloads {
          guard let id = payload["id"] as? String,
                let title = payload["title"] as? String,
                let startMs = (payload["startDate"] as? NSNumber)?.doubleValue,
                let endMs = (payload["endDate"] as? NSNumber)?.doubleValue else {
            continue
          }

          let startDate = Date(timeIntervalSince1970: startMs / 1000)
          let endDate = Date(timeIntervalSince1970: endMs / 1000)
          let event = self.existingEvent(for: id, in: calendar, startDate: startDate)
            ?? EKEvent(eventStore: self.eventStore)

          event.calendar = calendar
          event.title = title
          event.notes = payload["description"] as? String
          event.location = payload["location"] as? String
          event.startDate = startDate
          event.endDate = endDate
          event.isAllDay = false
          event.url = URL(string: "unihub://event/\(id)")

          try self.eventStore.save(event, span: .thisEvent, commit: false)
          syncedIds.append(id)
        }

        if !syncedIds.isEmpty {
          try self.eventStore.commit()
        }
        result(syncedIds)
      } catch {
        result(FlutterError(code: "calendar_sync_failed", message: error.localizedDescription, details: nil))
      }
    }
  }

  private func checkCalendarPermissionStatus(result: FlutterResult) {
    let status: String
    if #available(iOS 17.0, *) {
      switch EKEventStore.authorizationStatus(for: .event) {
      case .fullAccess:       status = "authorized"
      case .notDetermined:    status = "notDetermined"
      case .denied:           status = "denied"
      case .restricted:       status = "restricted"
      case .writeOnly:        status = "writeOnly"
      @unknown default:       status = "notDetermined"
      }
    } else {
      switch EKEventStore.authorizationStatus(for: .event) {
      case .authorized:       status = "authorized"
      case .notDetermined:    status = "notDetermined"
      case .denied:           status = "denied"
      case .restricted:       status = "restricted"
      @unknown default:       status = "notDetermined"
      }
    }
    result(status)
  }

  private func requestCalendarAccess(completion: @escaping (Bool) -> Void) {
    if #available(iOS 17.0, *) {
      eventStore.requestFullAccessToEvents { granted, _ in
        DispatchQueue.main.async {
          completion(granted)
        }
      }
    } else {
      eventStore.requestAccess(to: .event) { granted, _ in
        DispatchQueue.main.async {
          completion(granted)
        }
      }
    }
  }

  private func removeEventFromAppleCalendar(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let id = args["id"] as? String else {
      result(FlutterError(code: "bad_args", message: "Missing event id", details: nil))
      return
    }

    requestCalendarAccess { granted in
      guard granted else {
        result(false)
        return
      }

      do {
        let calendar = try self.unihubCalendar()
        if let event = self.existingEvent(for: id, in: calendar) {
          try self.eventStore.remove(event, span: .thisEvent, commit: true)
          result(true)
        } else {
          result(false)
        }
      } catch {
        result(FlutterError(code: "calendar_remove_failed", message: error.localizedDescription, details: nil))
      }
    }
  }

  private func unihubCalendar() throws -> EKCalendar {
    if let existing = eventStore.calendars(for: .event).first(where: {
      $0.title == "UniHub" && $0.allowsContentModifications
    }) {
      return existing
    }

    let calendar = EKCalendar(for: .event, eventStore: eventStore)
    calendar.title = "UniHub"
    calendar.cgColor = UIColor(red: 0.71, green: 0.11, blue: 0.09, alpha: 1.0).cgColor

    if let defaultSource = eventStore.defaultCalendarForNewEvents?.source {
      calendar.source = defaultSource
    } else if let localSource = eventStore.sources.first(where: { $0.sourceType == .local }) {
      calendar.source = localSource
    } else if let firstSource = eventStore.sources.first {
      calendar.source = firstSource
    } else {
      throw NSError(
        domain: "UniHubCalendar",
        code: 1,
        userInfo: [
          NSLocalizedDescriptionKey:
            "No calendar account is available. Open the Calendar app once, then try again."
        ]
      )
    }

    try eventStore.saveCalendar(calendar, commit: true)
    return calendar
  }

  private func existingEvent(for id: String, in calendar: EKCalendar, startDate: Date? = nil) -> EKEvent? {
    let anchorDate = startDate ?? Date()
    let range = startDate == nil ? 365 : 1
    let searchStart = Calendar.current.date(byAdding: .day, value: -range, to: anchorDate) ?? anchorDate
    let searchEnd = Calendar.current.date(byAdding: .day, value: range, to: anchorDate) ?? anchorDate
    let predicate = eventStore.predicateForEvents(
      withStart: searchStart,
      end: searchEnd,
      calendars: [calendar]
    )
    return eventStore.events(matching: predicate).first {
      $0.url?.absoluteString == "unihub://event/\(id)"
    }
  }

}
