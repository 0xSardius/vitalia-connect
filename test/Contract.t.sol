// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/VitaliaConnect.sol";

contract VitaliaConnectTest is Test {
    VitaliaConnect public connect;
    address public user1 = address(1);
    address public user2 = address(2);

    function setUp() public {
        connect = new VitaliaConnect();
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
    }

    function testCreateListing() public {
        vm.startPrank(user1);

        uint256 listingId = connect.createListing(
            "Test Project",
            "Description",
            "Biohacking",
            true,
            VitaliaConnect.ExpertiseType.OFFERING,
            "Programming",
            "test@example.com"
        );

        VitaliaConnect.Listing memory listing = connect.getListing(listingId);
        assertEq(listing.title, "Test Project");
        assertEq(listing.creator, user1);
        assertTrue(listing.active);

        vm.stopPrank();
    }

    function testUpdateListing() public {
        vm.startPrank(user1);

        uint256 listingId = connect.createListing(
            "Test Project",
            "Description",
            "Biohacking",
            true,
            VitaliaConnect.ExpertiseType.OFFERING,
            "Programming",
            "test@example.com"
        );

        connect.updateListing(
            listingId,
            "Updated Project",
            "New Description",
            "Biotech",
            VitaliaConnect.ExpertiseType.SEEKING,
            "Research",
            "new@example.com"
        );

        VitaliaConnect.Listing memory listing = connect.getListing(listingId);
        assertEq(listing.title, "Updated Project");
        assertEq(listing.category, "Biotech");

        vm.stopPrank();
    }

    function testFailUpdateListingNonOwner() public {
        vm.prank(user1);
        uint256 listingId = connect.createListing(
            "Test Project",
            "Description",
            "Biohacking",
            true,
            VitaliaConnect.ExpertiseType.OFFERING,
            "Programming",
            "test@example.com"
        );

        vm.prank(user2);
        connect.updateListing(
            listingId,
            "Updated Project",
            "New Description",
            "Biotech",
            VitaliaConnect.ExpertiseType.SEEKING,
            "Research",
            "new@example.com"
        );
    }
}
