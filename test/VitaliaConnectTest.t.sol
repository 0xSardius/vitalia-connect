// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/VitaliaConnect.sol";

contract VitaliaConnectTest is Test {
    VitaliaConnect public vitaliaConnect;
    
    address owner = address(1);
    address user1 = address(2);
    address user2 = address(3);
    address user3 = address(4);

    // Test data
    string[] expertiseAreas;

    function setUp() public {
        vm.startPrank(owner);
        vitaliaConnect = new VitaliaConnect();
        vm.stopPrank();

        expertiseAreas.push("Biohacking");
        expertiseAreas.push("Longevity");
    }

    function createDefaultProfile(address user) internal {
        vm.startPrank(user);
        vitaliaConnect.createProfile(
            "telegram:@user",    // contactInfo
            true,               // onSiteStatus
            "Staying until March", // travelDetails
            expertiseAreas,     // expertiseAreas
            "PhD in Longevity", // credentials
            "Researcher focused on aging" // bio
        );
        vm.stopPrank();
    }

    function test_CreateProfile() public {
        createDefaultProfile(user1);

        (
            bool isActive,
            string memory contactInfo,
            bool onSiteStatus,
            string memory travelDetails,
            uint256 lastStatusUpdate,
            string[] memory areas
        ) = vitaliaConnect.getProfile(user1);

        assertTrue(isActive);
        assertEq(contactInfo, "telegram:@user");
        assertTrue(onSiteStatus);
        assertEq(areas.length, expertiseAreas.length);
    }

    function test_RevertCreateDuplicateProfile() public {
        createDefaultProfile(user1);
        
        vm.startPrank(user1);
        vm.expectRevert("Profile exists");
        vitaliaConnect.createProfile(
            "telegram:@user",
            true,
            "Staying until March",
            expertiseAreas,
            "PhD in Longevity",
            "Researcher focused on aging"
        );
        vm.stopPrank();
    }

    function test_UpdateProfile() public {
        createDefaultProfile(user1);

        string[] memory newExpertise = new string[](1);
        newExpertise[0] = "NewExpertise";

        vm.startPrank(user1);
        vitaliaConnect.updateProfile(
            "new:@contact",
            false,
            "Updated travel",
            newExpertise,
            "Updated credentials",
            "Updated bio"
        );
        vm.stopPrank();

        (
            ,
            string memory contactInfo,
            bool onSiteStatus,
            string memory travelDetails,
            ,
            string[] memory areas
        ) = vitaliaConnect.getProfile(user1);

        assertEq(contactInfo, "new:@contact");
        assertFalse(onSiteStatus);
        assertEq(travelDetails, "Updated travel");
        assertEq(areas.length, 1);
        assertEq(areas[0], "NewExpertise");
    }

    function test_DeactivateProfile() public {
        createDefaultProfile(user1);

        vm.prank(user1);
        vitaliaConnect.deactivateProfile();

        (bool isActive,,,,,) = vitaliaConnect.getProfile(user1);
        assertFalse(isActive);
    }

    function test_CreateListing() public {
        createDefaultProfile(user1);

        vm.startPrank(user1);
        uint256 listingId = vitaliaConnect.createListing(
            "Need Longevity Expert",
            "Looking for advice",
            "Longevity Research",
            true,
            VitaliaConnect.ExpertiseType.SEEKING,
            "Clinical Trials",
            "telegram"
        );
        vm.stopPrank();

        VitaliaConnect.Listing memory listing = vitaliaConnect.getListing(listingId);
        assertEq(listing.title, "Need Longevity Expert");
        assertEq(listing.creator, user1);
        assertTrue(listing.active);
        assertEq(uint(listing.status), uint(0)); // Status.Open
    }

    function test_RevertCreateListingWithoutProfile() public {
        vm.startPrank(user3);
        vm.expectRevert("Must create profile first");
        vitaliaConnect.createListing(
            "Test Listing",
            "Description",
            "Biohacking",
            true,
            VitaliaConnect.ExpertiseType.SEEKING,
            "Expertise",
            "telegram"
        );
        vm.stopPrank();
    }

    function test_RespondToListing() public {
        createDefaultProfile(user1);
        createDefaultProfile(user2);

        vm.prank(user1);
        uint256 listingId = vitaliaConnect.createListing(
            "Test Listing",
            "Description",
            "Biohacking",
            true,
            VitaliaConnect.ExpertiseType.SEEKING,
            "Expertise",
            "telegram"
        );

        vm.prank(user2);
        vitaliaConnect.respondToListing(listingId);

        VitaliaConnect.Listing memory listing = vitaliaConnect.getListing(listingId);
        assertEq(uint(listing.status), uint(1)); // Status.InProgress
        assertEq(listing.responder, user2);
    }

    function test_MarkResolved() public {
        createDefaultProfile(user1);
        createDefaultProfile(user2);

        vm.prank(user1);
        uint256 listingId = vitaliaConnect.createListing(
            "Test Listing",
            "Description",
            "Biohacking",
            true,
            VitaliaConnect.ExpertiseType.SEEKING,
            "Expertise",
            "telegram"
        );

        vm.prank(user2);
        vitaliaConnect.respondToListing(listingId);

        vm.prank(user1);
        vitaliaConnect.markResolved(listingId);

        VitaliaConnect.Listing memory listing = vitaliaConnect.getListing(listingId);
        assertEq(uint(listing.status), uint(2)); // Status.Resolved
    }

    function test_ListingExpiration() public {
        createDefaultProfile(user1);

        vm.prank(user1);
        uint256 listingId = vitaliaConnect.createListing(
            "Test Listing",
            "Description",
            "Biohacking",
            true,
            VitaliaConnect.ExpertiseType.SEEKING,
            "Expertise",
            "telegram"
        );

        // Fast forward 16 days
        vm.warp(block.timestamp + 16 days);
        assertTrue(vitaliaConnect.isExpired(listingId));
    }

    function test_UserStats() public {
        createDefaultProfile(user1);
        createDefaultProfile(user2);

        vm.prank(user1);
        uint256 listingId = vitaliaConnect.createListing(
            "Test Listing",
            "Description",
            "Biohacking",
            true,
            VitaliaConnect.ExpertiseType.SEEKING,
            "Expertise",
            "telegram"
        );

        vm.prank(user2);
        vitaliaConnect.respondToListing(listingId);

        vm.prank(user1);
        vitaliaConnect.markResolved(listingId);

        (
            uint256 completed,
            uint256 created,
            uint256 responses,
            uint256 lastActive
        ) = vitaliaConnect.getUserStats(user1);

        assertEq(completed, 1);
        assertEq(created, 1);
        assertEq(responses, 0);
        assertTrue(lastActive > 0);

        (completed, created, responses, lastActive) = vitaliaConnect.getUserStats(user2);
        assertEq(completed, 1);
        assertEq(created, 0);
        assertEq(responses, 1);
    }

    function test_AdminFunctions() public {
        vm.startPrank(owner);
        vitaliaConnect.addCategory("New Category");
        string[] memory categories = vitaliaConnect.getCategories();
        bool found = false;
        for (uint i = 0; i < categories.length; i++) {
            if (keccak256(bytes(categories[i])) == keccak256(bytes("New Category"))) {
                found = true;
                break;
            }
        }
        assertTrue(found);

        vitaliaConnect.removeCategory("New Category");
        categories = vitaliaConnect.getCategories();
        found = false;
        for (uint i = 0; i < categories.length; i++) {
            if (keccak256(bytes(categories[i])) == keccak256(bytes("New Category"))) {
                found = true;
                break;
            }
        }
        assertFalse(found);
        vm.stopPrank();
    }

    function test_RevertNonOwnerAdminFunctions() public {
        vm.prank(user1);
        vm.expectRevert("Ownable: caller is not the owner");
        vitaliaConnect.addCategory("New Category");
    }

    function test_RevertSelfResponse() public {
        createDefaultProfile(user1);

        vm.prank(user1);
        uint256 listingId = vitaliaConnect.createListing(
            "Test Listing",
            "Description",
            "Biohacking",
            true,
            VitaliaConnect.ExpertiseType.SEEKING,
            "Expertise",
            "telegram"
        );

        vm.prank(user1);
        vm.expectRevert("Cannot respond to own listing");
        vitaliaConnect.respondToListing(listingId);
    }

    function test_RevertExpiredListingResponse() public {
        createDefaultProfile(user1);
        createDefaultProfile(user2);

        vm.prank(user1);
        uint256 listingId = vitaliaConnect.createListing(
            "Test Listing",
            "Description",
            "Biohacking",
            true,
            VitaliaConnect.ExpertiseType.SEEKING,
            "Expertise",
            "telegram"
        );

        vm.warp(block.timestamp + 16 days);

        vm.prank(user2);
        vm.expectRevert("Listing has expired");
        vitaliaConnect.respondToListing(listingId);
    }

    function test_GetProfilesByExpertise() public {
        createDefaultProfile(user1);
        createDefaultProfile(user2);

        (address[] memory addresses, VitaliaConnect.UserProfile[] memory profiles) = 
            vitaliaConnect.getProfilesByExpertise("Biohacking");

        assertEq(addresses.length, 2);
        assertTrue(profiles[0].isActive);
        assertTrue(profiles[1].isActive);
    }

    function test_GetProfilesByOnSiteStatus() public {
        createDefaultProfile(user1);
        
        vm.prank(user2);
        string[] memory expertise = new string[](1);
        expertise[0] = "Biohacking";
        vitaliaConnect.createProfile(
            "telegram:@user2",
            false, // not onsite
            "Remote",
            expertise,
            "Expert",
            "Bio"
        );

        (address[] memory onSiteAddresses,) = vitaliaConnect.getProfilesByOnSiteStatus(true);
        (address[] memory offSiteAddresses,) = vitaliaConnect.getProfilesByOnSiteStatus(false);

        assertEq(onSiteAddresses.length, 1);
        assertEq(offSiteAddresses.length, 1);
        assertEq(onSiteAddresses[0], user1);
        assertEq(offSiteAddresses[0], user2);
    }
}