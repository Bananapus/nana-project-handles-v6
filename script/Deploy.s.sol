// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Sphinx} from "@sphinx-labs/contracts/contracts/foundry/SphinxPlugin.sol";
import {Script} from "forge-std/Script.sol";

import {CoreDeploymentLib, CoreDeployment} from "@bananapus/core-v6/script/helpers/CoreDeploymentLib.sol";
import {JBProjectHandles} from "../src/JBProjectHandles.sol";

contract Deploy is Script, Sphinx {
    bytes32 constant PROJECT_HANDLES_SALT = "_JBProjectHandlesV6_";

    /// @notice The deployment of the core contracts for the chain we are deploying to.
    CoreDeployment core;

    function configureSphinx() public override {
        sphinxConfig.projectName = "project-handles-v6";
        sphinxConfig.mainnets = ["ethereum"];
        sphinxConfig.testnets = ["ethereum_sepolia"];
    }

    function run() public {
        // Get the deployment addresses for the nana CORE for this chain.
        core = CoreDeploymentLib.getDeployment(
            vm.envOr("NANA_CORE_DEPLOYMENT_PATH", string("node_modules/@bananapus/core-v6/deployments/"))
        );

        // Perform the deployment transactions.
        deploy();
    }

    function deploy() public sphinx {
        if (!_isDeployed({
                salt: PROJECT_HANDLES_SALT,
                creationCode: type(JBProjectHandles).creationCode,
                arguments: abi.encode(core.trustedForwarder)
            })) {
            new JBProjectHandles{salt: PROJECT_HANDLES_SALT}(core.trustedForwarder);
        }
    }

    function _isDeployed(bytes32 salt, bytes memory creationCode, bytes memory arguments) internal view returns (bool) {
        address _deployedTo = vm.computeCreate2Address({
            salt: salt,
            initCodeHash: keccak256(abi.encodePacked(creationCode, arguments)),
            // Arachnid/deterministic-deployment-proxy address.
            deployer: address(0x4e59b44847b379578588920cA78FbF26c0B4956C)
        });

        return address(_deployedTo).code.length != 0;
    }
}
