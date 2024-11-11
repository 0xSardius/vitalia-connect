// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/VitaliaConnect.sol";
import "../src/VitaliaProfiles.sol";

contract VitaliaConnectTest is Test {
    VitaliaConnect public connect;
    VitaliaProfiles public profiles;
    address public owner;
    address public user1;
    address public user2;

    event ListingCreated(
        uint256 indexed id,
        address indexed creator,
        string title,
        bool isProject,
        string category,
        uint256 timestamp
    );

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // Deploy both contracts
        profiles = new VitaliaProfiles();
        vm.prank(owner);
        profiles.setConnectContract(address(connect));
        connect = new VitaliaConnect(address(profiles));

        // Create profiles for testing
        string[] memory expertise = new string[](1);
        expertise[0] = "Biohacking";

        vm.startPrank(user1);
        profiles.createProfile(
            "telegram:@user1",
            true,
            "Arriving March 1",
            expertise,
            "PhD in Biology",
            "Researcher"
        );
        vm.stopPrank();

        vm.startPrank(user2);
        profiles.createProfile(
            "telegram:@user2",
            true,
            "Here",
            expertise,
            "MSc",
            "Another researcher"
        );
        vm.stopPrank();

        vm.label(user1, "User 1");
        vm.label(user2, "User 2");
    }

    function testInitialState() public {
        assertEq(connect.owner(), owner);
        assertTrue(connect.categoryExists("Biohacking"));
    }

    function testCreateListing() public {
        vm.startPrank(user1);
        
        vm.expectEmit(true, true, false, true);
        emit ListingCreated(1, user1, "Test Listing", true, "Biohacking", block.timestamp);
        
        uint256 listingId = connect.createListing(
            "Test Listing",
            "Need help with biohacking",
            "Biohacking",
            true,
            VitaliaConnect.ExpertiseType.SEEKING,
            "Peptides",
            "telegram:@user1"
        );

        VitaliaConnect.Listing memory listing = connect.getListing(listingId);
        assertEq(listing.title, "Test Listing");
        assertEq(listing.creator, user1);
        assertTrue(listing.active);
        assertEq(uint(listing.status), uint(VitaliaConnect.Status.Open));
        
        vm.stopPrank();
    }

    function testCannotCreateListingWithoutProfile() public {
        address noProfile = makeAddr("noProfile");
        
        vm.startPrank(noProfile);
        vm.expectRevert("Must create profile first");
        connect.createListing(
            "Test Listing",
            "Description",
            "Biohacking",
            true,
            VitaliaConnect.ExpertiseType.SEEKING,
            "Peptides",
            "telegram:@test"
        );
        vm.stopPrank();
    }

    function testRespondToListing() public {
        uint256 listingId = _createTestListing();

        vm.prank(user2);
        connect.respondToListing(listingId);

        VitaliaConnect.Listing memory listing = connect.getListing(listingId);
        assertEq(uint(listing.status), uint(VitaliaConnect.Status.InProgress));
        assertEq(listing.responder, user2);
    }

    function testCannotRespondToOwnListing() public {
        uint256 listingId = _createTestListing();

        vm.expectRevert("Cannot respond to own listing");
        vm.prank(user1);
        connect.respondToListing(listingId);
    }

    function testMarkResolved() public {
        uint256 listingId = _createTestListing();

        vm.prank(user2);
        connect.respondToListing(listingId);

        vm.prank(user1);
        connect.markResolved(listingId);

        VitaliaConnect.Listing memory listing = connect.getListing(listingId);
        assertEq(uint(listing.status), uint(VitaliaConnect.Status.Resolved));

        // Check that stats were updated
        (uint40 completed, uint40 created, uint40 responses, ) = profiles.getUserStats(user1);
        assertEq(completed, 1);
        
        // Optionally check responder's stats
        (completed, created, responses, ) = profiles.getUserStats(user2);
        assertEq(completed, 1);
    }
    
    function testListingExpiry() public {
        uint256 listingId = _createTestListing();
        
        // Move forward 16 days
        skip(16 days);
        
        assertTrue(connect.isExpired(listingId));

        // Should not be able to respond to expired listing
        vm.expectRevert("Listing has expired");
        vm.prank(user2);
        connect.respondToListing(listingId);
    }

    function testGetActiveListings() public {
        _createTestListing();
        _createTestListing();

        VitaliaConnect.Listing[] memory active = connect.getActiveListings();
        assertEq(active.length, 2);
    }

    function testGetListingsByStatus() public {
        uint256 listingId = _createTestListing();
        
        vm.prank(user2);
        connect.respondToListing(listingId);

        VitaliaConnect.Listing[] memory inProgress = connect.getListingsByStatus(VitaliaConnect.Status.InProgress);
        assertEq(inProgress.length, 1);
        assertEq(inProgress[0].id, listingId);
    }

    function testGetListingsByExpertise() public {
        _createTestListing();

        VitaliaConnect.Listing[] memory listings = connect.getListingsByExpertise("Peptides");
        assertEq(listings.length, 1);
        assertEq(listings[0].expertise, "Peptides");
    }

    function _createTestListing() internal returns (uint256) {
        vm.prank(user1);
        return connect.createListing(
            "Test Listing",
            "Need help with biohacking",
            "Biohacking",
            true,
            VitaliaConnect.ExpertiseType.SEEKING,
            "Peptides",
            "telegram:@user1"
        );
    }
}