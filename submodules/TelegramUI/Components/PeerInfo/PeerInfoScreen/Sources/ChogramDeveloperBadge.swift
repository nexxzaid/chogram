import Foundation
import UIKit
import Display
import TelegramCore
import AppBundle

private func chogramMintColor(isDark: Bool) -> UIColor {
    return isDark ? UIColor(rgb: 0x5EEAD4) : UIColor(rgb: 0x0F8F7E)
}

// The mint label under the name in a profile, for people with a Chogram badge.
final class ChogramDeveloperPillView: UIView {
    static let height: CGFloat = 28.0

    private let iconView: UIImageView
    private let titleLabel: UILabel

    override init(frame: CGRect) {
        self.iconView = UIImageView(image: UIImage(bundleImageName: "Chogram/BadgeSmall"))
        self.iconView.contentMode = .scaleAspectFit
        self.titleLabel = UILabel()
        self.titleLabel.font = Font.semibold(14.0)

        super.init(frame: frame)

        self.layer.cornerRadius = 12.0
        if #available(iOS 13.0, *) {
            self.layer.cornerCurve = .continuous
        }
        self.addSubview(self.iconView)
        self.addSubview(self.titleLabel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(title: String, isDark: Bool, isOutlined: Bool = false) -> CGSize {
        let mint = chogramMintColor(isDark: isDark)
        if isOutlined {
            self.backgroundColor = .clear
            self.layer.borderWidth = 1.0
            self.layer.borderColor = mint.withAlphaComponent(0.5).cgColor
        } else {
            self.backgroundColor = mint.withAlphaComponent(0.16)
            self.layer.borderWidth = 0.0
        }
        self.titleLabel.textColor = mint
        self.titleLabel.text = title

        let iconSize = CGSize(width: 17.0, height: 17.0)
        let titleSize = self.titleLabel.sizeThatFits(CGSize(width: 260.0, height: ChogramDeveloperPillView.height))
        let size = CGSize(width: 10.0 + iconSize.width + 7.0 + ceil(titleSize.width) + 12.0, height: ChogramDeveloperPillView.height)

        self.iconView.frame = CGRect(origin: CGPoint(x: 10.0, y: floor((size.height - iconSize.height) / 2.0)), size: iconSize)
        self.titleLabel.frame = CGRect(origin: CGPoint(x: 10.0 + iconSize.width + 7.0, y: floor((size.height - titleSize.height) / 2.0)), size: CGSize(width: ceil(titleSize.width), height: titleSize.height))
        return size
    }
}

struct ChogramBadgeSheetColors {
    let background: UIColor
    let cellBackground: UIColor
    let separator: UIColor
    let text: UIColor
    let secondaryText: UIColor
    let accent: UIColor
}

// The window behind the developer label. It is laid out like Telegram's own detail sheets
// (the wallet's transfer details): a close button, a large icon, a two-column table and one
// button, in the theme's colors. Only the badge itself stays mint.
final class ChogramBadgeSheetController: UIViewController {
    private let badge: ChogramBadge
    private let holderName: String
    private let isDark: Bool
    private let colors: ChogramBadgeSheetColors
    private let openAbout: () -> Void

    init(badge: ChogramBadge, holderName: String, isDark: Bool, colors: ChogramBadgeSheetColors, openAbout: @escaping () -> Void) {
        self.badge = badge
        self.holderName = holderName
        self.isDark = isDark
        self.colors = colors
        self.openAbout = openAbout

        super.init(nibName: nil, bundle: nil)

        self.modalPresentationStyle = .pageSheet
        if #available(iOS 13.0, *) {
            self.overrideUserInterfaceStyle = isDark ? .dark : .light
        }
        if #available(iOS 15.0, *), let sheet = self.sheetPresentationController {
            if #available(iOS 16.0, *) {
                sheet.detents = [.custom(resolver: { _ in
                    return 400.0
                })]
            } else {
                sheet.detents = [.medium()]
            }
            sheet.prefersGrabberVisible = false
            sheet.preferredCornerRadius = 32.0
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func roundButton(systemName: String) -> UIButton {
        let button = UIButton(type: .system)
        button.backgroundColor = self.colors.secondaryText.withAlphaComponent(0.16)
        button.tintColor = self.colors.text
        button.layer.cornerRadius = 20.0
        if #available(iOS 13.0, *) {
            button.setImage(UIImage(systemName: systemName, withConfiguration: UIImage.SymbolConfiguration(pointSize: 16.0, weight: .semibold)), for: .normal)
        }
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 40.0),
            button.heightAnchor.constraint(equalToConstant: 40.0)
        ])
        return button
    }

    private func tableView(rows: [(String, String, Bool)]) -> UIView {
        let table = UIView()
        table.layer.cornerRadius = 14.0
        table.layer.borderWidth = 1.0
        table.layer.borderColor = self.colors.separator.cgColor
        table.clipsToBounds = true
        if #available(iOS 13.0, *) {
            table.layer.cornerCurve = .continuous
        }

        let stack = UIStackView()
        stack.axis = .vertical
        stack.translatesAutoresizingMaskIntoConstraints = false
        table.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: table.topAnchor),
            stack.bottomAnchor.constraint(equalTo: table.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: table.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: table.trailingAnchor)
        ])

        for (index, row) in rows.enumerated() {
            if index != 0 {
                let line = UIView()
                line.backgroundColor = self.colors.separator
                line.heightAnchor.constraint(equalToConstant: 1.0).isActive = true
                stack.addArrangedSubview(line)
            }
            let rowView = UIView()
            let keyBackground = UIView()
            keyBackground.backgroundColor = self.colors.cellBackground
            let divider = UIView()
            divider.backgroundColor = self.colors.separator
            let key = UILabel()
            key.text = row.0
            key.font = Font.medium(15.0)
            key.textColor = self.colors.text
            let value = UILabel()
            value.text = row.1
            value.font = Font.regular(15.0)
            value.textColor = row.2 ? self.colors.accent : self.colors.text
            value.numberOfLines = 0
            for view in [keyBackground, divider, key, value] as [UIView] {
                view.translatesAutoresizingMaskIntoConstraints = false
                rowView.addSubview(view)
            }
            NSLayoutConstraint.activate([
                keyBackground.topAnchor.constraint(equalTo: rowView.topAnchor),
                keyBackground.bottomAnchor.constraint(equalTo: rowView.bottomAnchor),
                keyBackground.leadingAnchor.constraint(equalTo: rowView.leadingAnchor),
                keyBackground.widthAnchor.constraint(equalToConstant: 108.0),
                divider.topAnchor.constraint(equalTo: rowView.topAnchor),
                divider.bottomAnchor.constraint(equalTo: rowView.bottomAnchor),
                divider.leadingAnchor.constraint(equalTo: keyBackground.trailingAnchor),
                divider.widthAnchor.constraint(equalToConstant: 1.0),
                key.leadingAnchor.constraint(equalTo: rowView.leadingAnchor, constant: 12.0),
                key.trailingAnchor.constraint(lessThanOrEqualTo: keyBackground.trailingAnchor, constant: -8.0),
                key.centerYAnchor.constraint(equalTo: rowView.centerYAnchor),
                value.leadingAnchor.constraint(equalTo: divider.trailingAnchor, constant: 12.0),
                value.trailingAnchor.constraint(equalTo: rowView.trailingAnchor, constant: -12.0),
                value.topAnchor.constraint(equalTo: rowView.topAnchor, constant: 11.0),
                value.bottomAnchor.constraint(equalTo: rowView.bottomAnchor, constant: -11.0)
            ])
            stack.addArrangedSubview(rowView)
        }
        return table
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = self.colors.background

        let closeButton = self.roundButton(systemName: "xmark")
        closeButton.addTarget(self, action: #selector(self.closePressed), for: .touchUpInside)

        let iconView = UIImageView(image: UIImage(bundleImageName: "Chogram/Badge"))
        iconView.contentMode = .scaleAspectFit

        let titleLabel = UILabel()
        titleLabel.text = self.badge.title
        titleLabel.font = Font.bold(24.0)
        titleLabel.textColor = self.colors.text
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        let table = self.tableView(rows: [("Кто", self.holderName, true)])

        let aboutButton = UIButton(type: .system)
        aboutButton.setTitle("Что такое Чограм?", for: .normal)
        aboutButton.titleLabel?.font = Font.regular(16.0)
        aboutButton.setTitleColor(self.colors.accent, for: .normal)
        aboutButton.addTarget(self, action: #selector(self.aboutPressed), for: .touchUpInside)

        let okButton = UIButton(type: .system)
        okButton.setTitle("OK", for: .normal)
        okButton.titleLabel?.font = Font.semibold(17.0)
        okButton.setTitleColor(.white, for: .normal)
        okButton.backgroundColor = self.colors.accent
        okButton.layer.cornerRadius = 25.0
        okButton.addTarget(self, action: #selector(self.closePressed), for: .touchUpInside)

        for view in [closeButton, iconView, titleLabel, table, aboutButton, okButton] as [UIView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            self.view.addSubview(view)
        }

        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 16.0),
            closeButton.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 16.0),

            iconView.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 30.0),
            iconView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 76.0),
            iconView.heightAnchor.constraint(equalToConstant: 76.0),

            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 14.0),
            titleLabel.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 24.0),
            titleLabel.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -24.0),

            table.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20.0),
            table.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 16.0),
            table.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -16.0),

            aboutButton.topAnchor.constraint(equalTo: table.bottomAnchor, constant: 12.0),
            aboutButton.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),

            okButton.topAnchor.constraint(equalTo: aboutButton.bottomAnchor, constant: 12.0),
            okButton.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 24.0),
            okButton.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -24.0),
            okButton.heightAnchor.constraint(equalToConstant: 50.0)
        ])
    }

    @objc private func closePressed() {
        self.dismiss(animated: true, completion: nil)
    }

    @objc private func aboutPressed() {
        self.dismiss(animated: true, completion: { [openAbout = self.openAbout] in
            openAbout()
        })
    }
}
