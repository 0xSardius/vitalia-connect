// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract VitaliaProfiles {
    // ======== State Variables ========
    address public owner;
    address[] private allProfiles;
    mapping(string => address[]) private expertiseToProfiles;
    address public connectContract;

    // ======== Events ========
    event ProfileCreated(address indexed user, bool onSiteStatus, string[] expertiseAreas, uint256 timestamp);
    event ProfileUpdated(address indexed user, bool onSiteStatus, string[] expertiseAreas, uint256 timestamp);
    event ProfileDeactivated(address indexed user, uint256 timestamp);
    event ExpertiseUpdated(address indexed user, string[] oldExpertise, string[] newExpertise, uint256 timestamp);

    // ======== Structs ========
    struct UserProfile {
        bool isActive;
        string contactInfo;
        bool onSiteStatus;
        string travelDetails;
        uint256 lastStatusUpdate;
        string[] expertiseAreas;
        string credentials;
        string bio;
        uint40 listingsCompleted;
        uint256 lastActive;
        uint40 totalListingsCreated;
        uint40 totalResponses;
    }

    mapping(address => UserProfile) public userProfiles;

    // ======== Constructor ========
    constructor() {
        owner = msg.sender;
    }

    // ======== Modifiers ========
    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    // ======== External Functions ========
    function createProfile(
        string calldata _contactInfo,
        bool _onSiteStatus,
        string calldata _travelDetails,
        string[] memory _expertiseAreas,
        string calldata _credentials,
        string calldata _bio
    ) external {
        require(userProfiles[msg.sender].lastStatusUpdate == 0, "Profile exists");
        require(bytes(_contactInfo).length > 0, "Contact info required");
        require(bytes(_bio).length <= 1000, "Bio too long");

        userProfiles[msg.sender] = UserProfile({
            isActive: true,
            contactInfo: _contactInfo,
            onSiteStatus: _onSiteStatus,
            travelDetails: _travelDetails,
            lastStatusUpdate: block.timestamp,
            expertiseAreas: _expertiseAreas,
            credentials: _credentials,
            bio: _bio,
            listingsCompleted: 0,
            lastActive: block.timestamp,
            totalListingsCreated: 0,
            totalResponses: 0
        });

        allProfiles.push(msg.sender);
        for (uint256 i = 0; i < _expertiseAreas.length; i++) {
            expertiseToProfiles[_expertiseAreas[i]].push(msg.sender);
        }

        emit ProfileCreated(msg.sender, _onSiteStatus, _expertiseAreas, block.timestamp);
    }

    function updateProfile(
        string calldata _contactInfo,
        bool _onSiteStatus,
        string calldata _travelDetails,
        string[] memory _expertiseAreas,
        string calldata _credentials,
        string calldata _bio
    ) external {
        require(userProfiles[msg.sender].lastStatusUpdate > 0, "Profile not found");
        require(bytes(_bio).length <= 1000, "Bio too long");

        // Store old expertise for event
        string[] memory oldExpertise = userProfiles[msg.sender].expertiseAreas;

        // Remove from old expertise mappings
        for (uint256 i = 0; i < oldExpertise.length; i++) {
            _removeFromExpertiseMapping(msg.sender, oldExpertise[i]);
        }

        UserProfile storage profile = userProfiles[msg.sender];
        profile.contactInfo = _contactInfo;
        profile.onSiteStatus = _onSiteStatus;
        profile.travelDetails = _travelDetails;
        profile.expertiseAreas = _expertiseAreas;
        profile.credentials = _credentials;
        profile.bio = _bio;
        profile.lastStatusUpdate = block.timestamp;
        profile.lastActive = block.timestamp;

        // Add to new expertise mappings
        for (uint256 i = 0; i < _expertiseAreas.length; i++) {
            expertiseToProfiles[_expertiseAreas[i]].push(msg.sender);
        }

        emit ProfileUpdated(msg.sender, _onSiteStatus, _expertiseAreas, block.timestamp);
        emit ExpertiseUpdated(msg.sender, oldExpertise, _expertiseAreas, block.timestamp);
    }

    function deactivateProfile() external {
        require(userProfiles[msg.sender].lastStatusUpdate > 0, "Profile not found");
        userProfiles[msg.sender].isActive = false;
        emit ProfileDeactivated(msg.sender, block.timestamp);
    }

    function setConnectContract(address _connectContract) external {
        require(msg.sender == owner, "Only owner can set connect contract");
        connectContract = _connectContract;
    }

    // ======== View Functions ========

    function getProfile(address _user)
        external
        view
        returns (
            bool isActive,
            string memory contactInfo,
            bool onSiteStatus,
            string memory travelDetails,
            uint256 lastStatusUpdate,
            string[] memory expertiseAreas,
            string memory credentials,
            string memory bio
        )
    {
        UserProfile storage profile = userProfiles[_user];
        return (
            profile.isActive,
            profile.contactInfo,
            profile.onSiteStatus,
            profile.travelDetails,
            profile.lastStatusUpdate,
            profile.expertiseAreas,
            profile.credentials,
            profile.bio
        );
    }

    function getUserStats(address _user) external view returns (
        uint40 completed,
        uint40 created,
        uint40 responses,
        uint256 lastActive
    ) {
        UserProfile storage profile = userProfiles[_user];
        return (
            profile.listingsCompleted,
            profile.totalListingsCreated,
            profile.totalResponses,
            profile.lastActive
        );
    }

    function getProfilesByExpertise(string calldata _expertise)
        external
        view
        returns (address[] memory matchingProfiles)
    {
        return expertiseToProfiles[_expertise];
    }

    function getAllActiveProfiles()
        external
        view
        returns (address[] memory activeAddresses)
    {
        uint256 activeCount = 0;
        
        // First pass to count active profiles
        for (uint256 i = 0; i < allProfiles.length; i++) {
            if (userProfiles[allProfiles[i]].isActive) {
                activeCount++;
            }
        }

        // Initialize array with correct size
        activeAddresses = new address[](activeCount);

        // Second pass to fill array
        uint256 currentIndex = 0;
        for (uint256 i = 0; i < allProfiles.length; i++) {
            if (userProfiles[allProfiles[i]].isActive) {
                activeAddresses[currentIndex] = allProfiles[i];
                currentIndex++;
            }
        }

        return activeAddresses;
    }

    function getProfilesByOnSiteStatus(bool _onSite) 
        external 
        view 
        returns (address[] memory filteredAddresses) 
    {
        uint256 count = 0;
        
        // First pass to count matching profiles
        for (uint256 i = 0; i < allProfiles.length; i++) {
            if (userProfiles[allProfiles[i]].isActive && 
                userProfiles[allProfiles[i]].onSiteStatus == _onSite) {
                count++;
            }
        }

        // Initialize array with correct size
        filteredAddresses = new address[](count);
        
        // Second pass to fill array
        uint256 currentIndex = 0;
        for (uint256 i = 0; i < allProfiles.length; i++) {
            if (userProfiles[allProfiles[i]].isActive && 
                userProfiles[allProfiles[i]].onSiteStatus == _onSite) {
                filteredAddresses[currentIndex] = allProfiles[i];
                currentIndex++;
            }
        }

        return filteredAddresses;
    }

    // ======== Internal Functions ========
    function _removeFromExpertiseMapping(address _profile, string memory _expertise) internal {
        address[] storage profiles = expertiseToProfiles[_expertise];
        for (uint256 i = 0; i < profiles.length; i++) {
            if (profiles[i] == _profile) {
                profiles[i] = profiles[profiles.length - 1];
                profiles.pop();
                break;
            }
        }
    }

    // ======== Admin Functions ========
    function updateProfileStats(
        address _user, 
        uint40 _listingsCompleted,
        uint40 _totalListingsCreated,
        uint40 _totalResponses
    ) external {
        // This will be restricted to VitaliaConnect contract in the next step
        UserProfile storage profile = userProfiles[_user];
        profile.listingsCompleted = _listingsCompleted;
        profile.totalListingsCreated = _totalListingsCreated;
        profile.totalResponses = _totalResponses;
        profile.lastActive = block.timestamp;
    }
} 