// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {Script} from "@forge/Script.sol";
import {Tester} from "src/Tester.sol";

contract Deploy is Script {
    function run() public payable returns (Tester tester) {
        vm.startBroadcast();
        tester = new Tester();
        vm.stopBroadcast();
    }
}
