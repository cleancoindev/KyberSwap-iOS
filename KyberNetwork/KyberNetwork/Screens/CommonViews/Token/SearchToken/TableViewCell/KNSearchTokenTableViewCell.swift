// Copyright SIX DAY LLC. All rights reserved.

import UIKit
import BigInt

class KNSearchTokenTableViewCell: UITableViewCell {

  @IBOutlet weak var iconImageView: UIImageView!
  @IBOutlet weak var tokenNameLabel: UILabel!
  @IBOutlet weak var tokenSymbolLabel: UILabel!
  @IBOutlet weak var balanceLabel: UILabel!

  override func awakeFromNib() {
    super.awakeFromNib()
    self.tokenNameLabel.text = ""
    self.tokenSymbolLabel.text = ""
  }

  func updateCell(with token: TokenObject, balance: Balance?) {
    if !token.isSupported {
      // if token is not supported, always use
      self.iconImageView.image = UIImage(named: "default_token")
    } else if let image = UIImage(named: token.icon.lowercased()) {
      self.iconImageView.image = image
    } else {
      self.iconImageView.setImage(
        with: token.iconURL,
        placeholder: UIImage(named: "default_token"))
    }
    self.tokenSymbolLabel.text = "\(token.symbol.prefix(8))"
    self.tokenSymbolLabel.addLetterSpacing()
    self.tokenNameLabel.text = token.name
    self.tokenNameLabel.addLetterSpacing()
    let balText: String = {
      let value = balance?.value.string(
        decimals: token.decimals,
        minFractionDigits: 0,
        maxFractionDigits: min(token.decimals, 6)
      )
      if let val = value, let double = Double(val.removeGroupSeparator()), double == 0 { return "0" }
      return value ?? ""
    }()
    self.balanceLabel.text = "\(balText.prefix(12))"
    self.balanceLabel.addLetterSpacing()
    self.layoutIfNeeded()
  }
}
