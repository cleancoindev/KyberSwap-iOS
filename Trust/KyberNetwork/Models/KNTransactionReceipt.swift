// Copyright SIX DAY LLC. All rights reserved.

import BigInt

struct KNTransactionReceipt: Decodable {
  let id: String
  let index: String
  let blockHash: String
  let blockNumber: String
  let gasUsed: String
  let cumulativeGasUsed: String
  let contractAddress: String
  let logsData: String
  let logsBloom: String
  let status: String
}

extension KNTransactionReceipt {
  static func from(_ dictionary: JSONDictionary) -> KNTransactionReceipt? {
    let id = dictionary["transactionHash"] as? String ?? ""
    let index = dictionary["transactionIndex"] as? String ?? ""
    let blockHash = dictionary["blockHash"] as? String ?? ""
    let blockNumber = dictionary["blockNumber"] as? String ?? ""
    let cumulativeGasUsed = dictionary["cumulativeGasUsed"] as? String ?? ""
    let gasUsed = dictionary["gasUsed"] as? String ?? ""
    let contractAddress = dictionary["contractAddress"] as? String ?? ""
    let customRPC: KNCustomRPC = KNEnvironment.default.knCustomRPC!
    let logsData: String = {
      if let logs: [JSONDictionary] = dictionary["logs"] as? [JSONDictionary] {
        for log in logs {
          let address = log["address"] as? String ?? ""
          let topics = log["topics"] as? [String] ?? []
          let data = log["data"] as? String ?? ""
          if address == customRPC.networkAddress, topics.first == customRPC.tradeTopic {
            return data
          }
        }
      }
      return ""
    }()

    let logsBloom = dictionary["logsBloom"] as? String ?? ""
    let status = dictionary["status"] as? String ?? ""

    return KNTransactionReceipt(
      id: id,
      index: index.drop0x,
      blockHash: blockHash,
      blockNumber: BigInt(blockNumber.drop0x, radix: 16)?.description ?? "",
      gasUsed: BigInt(gasUsed.drop0x, radix: 16)?.description ?? "",
      cumulativeGasUsed: BigInt(cumulativeGasUsed.drop0x, radix: 16)?.description ?? "",
      contractAddress: contractAddress,
      logsData: logsData,
      logsBloom: logsBloom,
      status: status.drop0x
    )
  }
}

extension KNTransactionReceipt {

  func toTransaction(from transaction: Transaction, logsDict: JSONDictionary?) -> Transaction {
    let localObjects: [LocalizedOperationObject] = {
      guard let json = logsDict else {
        return Array(transaction.localizedOperations)
      }
      let (valueString, decimals): (String, Int) = {
        let value = BigInt(json["destAmount"] as? String ?? "") ?? BigInt(0)
        if let token = KNJSONLoaderUtil.loadListSupportedTokensFromJSONFile().first(where: { $0.address == (json["dest"] as? String ?? "").lowercased() }) {
          return (value.fullString(decimals: token.decimal), token.decimal)
        }
        return (value.fullString(units: .ether), 18)
      }()
      let localObject = LocalizedOperationObject(
        from: (json["src"] as? String ?? "").lowercased(),
        to: (json["dest"] as? String ?? "").lowercased(),
        contract: nil,
        type: "exchange",
        value: valueString,
        symbol: nil,
        name: nil,
        decimals: decimals
      )
      return [localObject]
    }()
    let newTransaction = Transaction(
      id: transaction.id,
      blockNumber: Int(self.blockNumber) ?? transaction.blockNumber,
      from: transaction.from,
      to: transaction.to,
      value: transaction.value,
      gas: transaction.gas,
      gasPrice: transaction.gasPrice,
      gasUsed: self.gasUsed,
      nonce: transaction.nonce,
      date: transaction.date,
      localizedOperations: localObjects,
      state: self.status == "1" ? .completed : .failed
    )
    return newTransaction
  }
}