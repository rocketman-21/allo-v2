// SPDX-License Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {IStrategy} from "../../../contracts/core/interfaces/IStrategy.sol";
import {QVBaseStrategy} from "../../../contracts/strategies/qv-base/QVBaseStrategy.sol";

// Test libraries
import {QVBaseStrategyTest} from "./QVBaseStrategy.t.sol";
import {MockERC20Vote} from "../../utils/MockERC20Vote.sol";
import {MockERC20} from "../../utils/MockERC20.sol";

// Core contracts
import {QVRevolutionVotingPower} from "../../../contracts/strategies/_poc/qv-revolution-governance/QVRevolutionVotingPower.sol";
import {IRevolutionVotingPower} from "../../../contracts/strategies/_poc/qv-revolution-governance/interfaces/IRevolutionVotingPower.sol";

contract QVRevolutionVotingPowerTest is QVBaseStrategyTest {
    IRevolutionVotingPower public votingPower;
    uint256 public timestamp;

    function setUp() public override {
        votingPower = IRevolutionVotingPower(address(new MockERC20Vote()));
        timestamp = block.timestamp;
        super.setUp();
    }

    function _createStrategy() internal override returns (address payable) {
        return payable(address(new QVRevolutionVotingPower(address(allo()), "MockStrategy")));
    }

    function qvGovStrategy() internal view returns (QVRevolutionVotingPower) {
        return (QVRevolutionVotingPower(_strategy));
    }

    function _initialize() internal override {
        vm.startPrank(pool_admin());
        _createPoolWithCustomStrategy();
    }

    function _createPoolWithCustomStrategy() internal override {
        poolId = allo().createPoolWithCustomStrategy(
            poolProfile_id(),
            address(_strategy),
            abi.encode(
                QVRevolutionVotingPower.InitializeParamsGov(
                    address(votingPower),
                    timestamp,
                    QVBaseStrategy.InitializeParams(
                        registryGating,
                        metadataRequired,
                        2,
                        registrationStartTime,
                        registrationEndTime,
                        allocationStartTime,
                        allocationEndTime
                    )
                )
            ),
            address(token),
            0 ether, // TODO: setup tests for failed transfers when a value is passed here.
            poolMetadata,
            pool_managers()
        );
    }

    function test_isValidAllocator() public override {
        assertFalse(qvGovStrategy().isValidAllocator(address(123)));
        assertTrue(qvGovStrategy().isValidAllocator(randomAddress()));
    }

    function testRevert_initialize_ALREADY_INITIALIZED() public override {
        vm.expectRevert(ALREADY_INITIALIZED.selector);

        vm.startPrank(address(allo()));
        QVRevolutionVotingPower(_strategy).initialize(
            poolId,
            abi.encode(
                QVRevolutionVotingPower.InitializeParamsGov(
                    address(votingPower),
                    timestamp,
                    QVBaseStrategy.InitializeParams(
                        registryGating,
                        metadataRequired,
                        2,
                        registrationStartTime,
                        registrationEndTime,
                        allocationStartTime,
                        allocationEndTime
                    )
                )
            )
        );
    }

    function test_initilize_QVGovernance() public {
        assertEq(address(votingPower), address(qvGovStrategy().votingPower()));
        assertEq(timestamp, qvGovStrategy().timestamp());
    }

    function testRevert_initialize_noVotingPower() public {
        QVRevolutionVotingPower strategy = new QVRevolutionVotingPower(address(allo()), "MockStrategy");
        MockERC20 noVotingPower = new MockERC20();
        // when no valid governance token is passes

        vm.expectRevert();
        vm.startPrank(address(allo()));
        strategy.initialize(
            poolId,
            abi.encode(
                QVRevolutionVotingPower.InitializeParamsGov(
                    address(noVotingPower),
                    timestamp,
                    QVBaseStrategy.InitializeParams(
                        registryGating,
                        metadataRequired,
                        2,
                        registrationStartTime,
                        registrationEndTime,
                        allocationStartTime,
                        allocationEndTime
                    )
                )
            )
        );
    }

    function testRevert_initialize_INVALID() public override {
        QVRevolutionVotingPower strategy = new QVRevolutionVotingPower(address(allo()), "MockStrategy");

        // when registrationStartTime is in the past
        vm.expectRevert(INVALID.selector);
        vm.startPrank(address(allo()));
        strategy.initialize(
            poolId,
            abi.encode(
                QVRevolutionVotingPower.InitializeParamsGov(
                    address(votingPower),
                    timestamp,
                    QVBaseStrategy.InitializeParams(
                        registryGating,
                        metadataRequired,
                        2,
                        uint64(today() - 1),
                        registrationEndTime,
                        allocationStartTime,
                        allocationEndTime
                    )
                )
            )
        );

        // when registrationStartTime > registrationEndTime
        vm.expectRevert(INVALID.selector);
        vm.startPrank(address(allo()));
        strategy.initialize(
            poolId,
            abi.encode(
                QVRevolutionVotingPower.InitializeParamsGov(
                    address(votingPower),
                    timestamp,
                    QVBaseStrategy.InitializeParams(
                        registryGating,
                        metadataRequired,
                        2,
                        uint64(weekAfterNext()),
                        registrationEndTime,
                        allocationStartTime,
                        allocationEndTime
                    )
                )
            )
        );

        // when allocationStartTime > allocationEndTime
        vm.expectRevert(INVALID.selector);
        vm.stopPrank();
        vm.startPrank(address(allo()));
        strategy.initialize(
            poolId,
            abi.encode(
                QVRevolutionVotingPower.InitializeParamsGov(
                    address(votingPower),
                    timestamp,
                    QVBaseStrategy.InitializeParams(
                        registryGating,
                        metadataRequired,
                        2,
                        registrationStartTime,
                        registrationEndTime,
                        uint64(oneMonthFromNow() + today()),
                        allocationEndTime
                    )
                )
            )
        );

        // when  registrationEndTime > allocationEndTime
        vm.expectRevert(INVALID.selector);
        vm.startPrank(address(allo()));
        strategy.initialize(
            poolId,
            abi.encode(
                QVRevolutionVotingPower.InitializeParamsGov(
                    address(votingPower),
                    timestamp,
                    QVBaseStrategy.InitializeParams(
                        registryGating,
                        metadataRequired,
                        2,
                        registrationStartTime,
                        uint64(oneMonthFromNow() + today()),
                        allocationStartTime,
                        allocationEndTime
                    )
                )
            )
        );
    }

    function testRevert_allocate_RECIPIENT_ERROR() public {
        address recipientId = __register_reject_recipient();
        address allocator = randomAddress();

        vm.expectRevert(abi.encodeWithSelector(RECIPIENT_ERROR.selector, recipientId));
        vm.warp(allocationStartTime + 10);

        bytes memory allocateData = __generateAllocation(recipientId, 4);
        vm.startPrank(address(allo()));
        qvGovStrategy().allocate(allocateData, allocator);
    }

    function testRevert_allocate_INVALID_tooManyVoiceCredits() public {
        address recipientId = __register_accept_recipient();
        address allocator = randomAddress();

        vm.expectRevert(abi.encodeWithSelector(INVALID.selector));
        vm.warp(allocationStartTime + 10);

        bytes memory allocateData = __generateAllocation(recipientId, 4000);

        vm.startPrank(address(allo()));
        qvGovStrategy().allocate(allocateData, allocator);
    }

    function testRevert_allocate_INVALID_noVoiceTokens() public {
        address recipientId = __register_accept_recipient();
        vm.warp(allocationStartTime + 10);

        address allocator = randomAddress();
        bytes memory allocateData = __generateAllocation(recipientId, 0);

        vm.expectRevert(INVALID.selector);
        vm.startPrank(address(allo()));
        qvGovStrategy().allocate(allocateData, allocator);
    }
}
