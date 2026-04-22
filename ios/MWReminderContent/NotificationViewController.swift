//
//  NotificationViewController.swift
//  MWReminderContent
//
//  Purpose: Notification Content Extension. When the daily study reminder
//           fires, iOS hands the notification to this controller (bundled
//           with the app under UNNotificationExtensionCategory =
//           "MW_STUDY_REMINDER"). We read the latest due count that the app
//           process wrote to the shared App Group and render a one-liner
//           body so the preview shows the live number.
//
//  Dependencies: UIKit, UserNotifications, UserNotificationsUI.
//

import UIKit
import UserNotifications
import UserNotificationsUI

final class NotificationViewController: UIViewController, UNNotificationContentExtension {
    private let label = UILabel()

    override func loadView() {
        let root = UIView()
        root.backgroundColor = .systemBackground
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: 18, weight: .regular)
        label.textColor = .label
        root.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -16),
            label.topAnchor.constraint(equalTo: root.topAnchor, constant: 16),
            label.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -16),
        ])
        view = root
    }

    func didReceive(_ notification: UNNotification) {
        let shared = UserDefaults(suiteName: "group.com.lukehogan.flashcards")
        let dueCount = shared?.integer(forKey: "mw.dueCount") ?? 0

        label.text =
            dueCount == 0
            ? "All caught up. Nothing due right now."
            : "\(dueCount) \(dueCount == 1 ? "card is" : "cards are") waiting for you."

        preferredContentSize = CGSize(
            width: view.bounds.width,
            height: label.sizeThatFits(CGSize(width: view.bounds.width - 32, height: .infinity)).height + 32,
        )
    }
}
