// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {stdJson} from "forge-std/Script.sol";
import {Vm} from "forge-std/Vm.sol";
import {SphinxConstants, NetworkInfo} from "@sphinx-labs/contracts/contracts/foundry/SphinxConstants.sol";

import {IJBProjectHandles} from "../../src/interfaces/IJBProjectHandles.sol";

struct ProjectHandlesDeployment {
    IJBProjectHandles projectHandles;
}

library ProjectHandlesDeploymentLib {
    // Cheat code address, 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D.
    address internal constant VM_ADDRESS = address(uint160(uint256(keccak256("hevm cheat code"))));
    Vm internal constant vm = Vm(VM_ADDRESS);

    function getDeployment(string memory path) internal returns (ProjectHandlesDeployment memory deployment) {
        uint256 chainId = block.chainid;

        SphinxConstants sphinxConstants = new SphinxConstants();
        NetworkInfo[] memory networks = sphinxConstants.getNetworkInfoArray();

        for (uint256 _i; _i < networks.length; _i++) {
            if (networks[_i].chainId == chainId) {
                return getDeployment({path: path, networkName: networks[_i].name});
            }
        }

        revert("ChainID is not (currently) supported by Sphinx.");
    }

    function getDeployment(
        string memory path,
        string memory networkName
    )
        internal
        view
        returns (ProjectHandlesDeployment memory deployment)
    {
        deployment.projectHandles = IJBProjectHandles(
            _getDeploymentAddress({
                path: path,
                projectName: "project-handles-v6",
                networkName: networkName,
                contractName: "JBProjectHandles"
            })
        );
    }

    function _getDeploymentAddress(
        string memory path,
        string memory projectName,
        string memory networkName,
        string memory contractName
    )
        internal
        view
        returns (address)
    {
        string memory deploymentJson =
            vm.readFile(string.concat(path, projectName, "/", networkName, "/", contractName, ".json"));
        return stdJson.readAddress({json: deploymentJson, key: ".address"});
    }
}
