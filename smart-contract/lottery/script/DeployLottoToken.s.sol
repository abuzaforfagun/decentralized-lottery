// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {LottoToken} from "../src/LottoToken.sol";

contract DeployLottoToken is Script {
    uint256 private constant INITIAL_SUPPLY = 1_000_000 * 10 ** 18;

    function run(address owner) public returns (LottoToken) {
        LottoToken lottoToken = new LottoToken(owner, INITIAL_SUPPLY);
        return lottoToken;
    }
}
