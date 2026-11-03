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

    func update(title: String, isDark: Bool) -> CGSize {
        let mint = chogramMintColor(isDark: isDark)
        self.backgroundColor = mint.withAlphaComponent(0.16)
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

// The sheet that opens when someone taps the badge.
final class ChogramBadgeSheetController: UIViewController {
    private let badge: ChogramBadge
    private let isDark: Bool
    private let backgroundColor: UIColor
    private let textColor: UIColor
    private let secondaryTextColor: UIColor

    init(badge: ChogramBadge, isDark: Bool, backgroundColor: UIColor, textColor: UIColor, secondaryTextColor: UIColor) {
        self.badge = badge
        self.isDark = isDark
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.secondaryTextColor = secondaryTextColor

        super.init(nibName: nil, bundle: nil)

        self.modalPresentationStyle = .pageSheet
        if #available(iOS 13.0, *) {
            self.overrideUserInterfaceStyle = isDark ? .dark : .light
        }
        if #available(iOS 15.0, *), let sheet = self.sheetPresentationController {
            if #available(iOS 16.0, *) {
                sheet.detents = [.custom(resolver: { _ in
                    return 300.0
                })]
            } else {
                sheet.detents = [.medium()]
            }
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 24.0
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let mint = chogramMintColor(isDark: self.isDark)
        self.view.backgroundColor = self.backgroundColor

        let iconView = UIImageView(image: UIImage(bundleImageName: "Chogram/Badge"))
        iconView.contentMode = .scaleAspectFit

        let titleLabel = UILabel()
        titleLabel.text = self.badge.title
        titleLabel.font = Font.bold(21.0)
        titleLabel.textColor = self.textColor
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        let textLabel = UILabel()
        textLabel.text = self.badge.description ?? "Этот человек создал клиент, которым ты пользуешься."
        textLabel.font = Font.regular(16.0)
        textLabel.textColor = self.secondaryTextColor
        textLabel.textAlignment = .center
        textLabel.numberOfLines = 0

        let button = UIButton(type: .system)
        button.setTitle("Понятно", for: .normal)
        button.titleLabel?.font = Font.semibold(17.0)
        button.setTitleColor(self.isDark ? UIColor(rgb: 0x04201C) : .white, for: .normal)
        button.backgroundColor = mint
        button.layer.cornerRadius = 14.0
        if #available(iOS 13.0, *) {
            button.layer.cornerCurve = .continuous
        }
        button.addTarget(self, action: #selector(self.closePressed), for: .touchUpInside)

        for view in [iconView, titleLabel, textLabel, button] as [UIView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            self.view.addSubview(view)
        }

        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 32.0),
            iconView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 64.0),
            iconView.heightAnchor.constraint(equalToConstant: 64.0),

            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 12.0),
            titleLabel.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 24.0),
            titleLabel.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -24.0),

            textLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6.0),
            textLabel.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 24.0),
            textLabel.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -24.0),

            button.topAnchor.constraint(equalTo: textLabel.bottomAnchor, constant: 22.0),
            button.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 18.0),
            button.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -18.0),
            button.heightAnchor.constraint(equalToConstant: 50.0)
        ])
    }

    @objc private func closePressed() {
        self.dismiss(animated: true, completion: nil)
    }
}
