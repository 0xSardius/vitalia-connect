// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./VitaliaProfiles.sol";

interface IVitaliaProfiles {
    function getProfile(address _user) external view returns (
        bool isActive,
        string memory contactInfo,
        bool onSiteStatus,
        string memory travelDetails,
        uint256 lastStatusUpdate,
        string[] memory expertiseAreas,
        string memory credentials,
        string memory bio
    );
    
    function updateProfileStats(
        address _user, 
        uint40 _listingsCompleted,
        uint40 _totalListingsCreated,
        uint40 _totalResponses
    ) external;

    function getUserStats(address _user) external view returns (
        uint40 completed,
        uint40 created,
        uint40 responses,
        uint256 lastActive
    );
}

/**
 * @title VitaliaConnect
 * @dev A platform for connecting individuals in the Vitalia community through projects and opportunities
 */
contract VitaliaConnect is Ownable, ReentrancyGuard {
    // ======== State Variables ========
    
    /// @dev Categories available for listings
    string[] public categories;
    
    /// @dev Tracks if a category exists
    mapping(string => bool) public categoryExists;

    /// @dev Counter for listing IDs
    uint256 private _listingIdCounter;

    /// @dev Reference to VitaliaProfiles contract
    IVitaliaProfiles public profilesContract;

    // ======== Type Definitions ========

    /// @dev Enum to define the type of expertise being offered/sought
    enum ExpertiseType { SEEKING, OFFERING }

    /// @dev Enum to define the status of a listing
    enum Status {
        Open,        // Initial state when listing is created
        InProgress,  // Expert has responded and begun helping
        Resolved,    // Creator has marked the help as complete
        Expired      // 15 days have passed without resolution
    }

    /// @dev Main struct for project/opportunity listings
    struct Listing {
        uint256 id;
        address creator;
        string title;
        string description;
        string category;
        bool isProject;           // true = project, false = opportunity
        ExpertiseType expertiseType;
        string expertise;
        string contactMethod;
        uint256 timestamp;
        bool active;
        Status status;
        address responder;
    }

    // ======== Storage ========

    /// @dev Mapping from listing ID to Listing struct
    mapping(uint256 => Listing) public listings;
    
    /// @dev Mapping from address to array of listing IDs
    mapping(address => uint256[]) public userListings;

    // ======= Modifiers =======

    modifier requiresProfile() {
        (bool isActive,,,,uint256 lastStatusUpdate,,,) = profilesContract.getProfile(msg.sender);
        require(lastStatusUpdate > 0, "Must create profile first");
        require(isActive, "Profile must be active");
        _;
    }

    // ======= Constants =======
    uint256 public constant LISTING_DURATION = 15 days;

    // ======== Events ========

    event ListingCreated(
        uint256 indexed id,
        address indexed creator,
        string title,
        bool isProject,
        string category,
        uint256 timestamp
    );

    event ListingUpdated(
        uint256 indexed id,
        string title,
        string category,
        uint256 timestamp
    );

    event ListingDeactivated(uint256 indexed id, uint256 timestamp);
    event CategoryAdded(string category);
    event CategoryRemoved(string category);
    event ListingResponded(uint256 indexed id, address indexed responder, uint256 timestamp);
    event ListingResolved(uint256 indexed id, uint256 timestamp);
    event ListingExpired(uint256 indexed id, uint256 timestamp);

    // ======== Constructor ========

    constructor(address _profilesContract) Ownable(msg.sender) {
        require(_profilesContract != address(0), "Invalid profiles contract");
        profilesContract = IVitaliaProfiles(_profilesContract);
        
        // Initialize with default categories
        _addCategory("Biohacking");
        _addCategory("Longevity Research");
        _addCategory("Biotech");
        _addCategory("Community Building");
        _addCategory("Governance");
        _addCategory("Technology");
    }

    // ======== External Functions ========

    function createListing(
        string calldata _title,
        string calldata _description,
        string calldata _category,
        bool _isProject,
        ExpertiseType _expertiseType,
        string calldata _expertise,
        string calldata _contactMethod
    ) external nonReentrant requiresProfile returns (uint256) {
        _validateListingInputs(_title, _description, _category);
        uint256 newListingId = _getNextListingId();
        _createListingStorage(
            newListingId,
            _title,
            _description,
            _category,
            _isProject,
            _expertiseType,
            _expertise,
            _contactMethod
        );
        _updateUserListings(newListingId);
        _emitListingCreated(newListingId, _title, _isProject, _category);

        // Update profile stats
        (uint40 completed, uint40 created, uint40 responses,) = profilesContract.getUserStats(msg.sender);
        profilesContract.updateProfileStats(
            msg.sender,
            completed,
            created + 1,
            responses
        );
        
        return newListingId;
    }

    function updateListing(
        uint256 _id,
        string calldata _title,
        string calldata _description,
        string calldata _category,
        ExpertiseType _expertiseType,
        string calldata _expertise,
        string calldata _contactMethod
    ) external nonReentrant {
        require(listings[_id].status == Status.Open, "Cannot update non-open listing");
        require(!isExpired(_id), "Listing has expired");
        require(_exists(_id), "Listing does not exist");
        require(listings[_id].creator == msg.sender, "Not the listing creator");
        require(listings[_id].active, "Listing is not active");
        require(categoryExists[_category], "Invalid category");

        Listing storage listing = listings[_id];
        listing.title = _title;
        listing.description = _description;
        listing.category = _category;
        listing.expertiseType = _expertiseType;
        listing.expertise = _expertise;
        listing.contactMethod = _contactMethod;

        emit ListingUpdated(_id, _title, _category, block.timestamp);
    }

    function respondToListing(uint256 _id) external nonReentrant requiresProfile {
        require(_exists(_id), "Listing does not exist");
        require(listings[_id].active, "Listing not active");
        require(listings[_id].status == Status.Open, "Listing not open");
        require(listings[_id].creator != msg.sender, "Cannot respond to own listing");
        require(!isExpired(_id), "Listing has expired");

        Listing storage listing = listings[_id];
        listing.status = Status.InProgress;
        listing.responder = msg.sender;

        // Update profile stats
        (uint40 completed, uint40 created, uint40 responses,) = profilesContract.getUserStats(msg.sender);
        profilesContract.updateProfileStats(
            msg.sender,
            completed,
            created,
            responses + 1
        );

        emit ListingResponded(_id, msg.sender, block.timestamp);
    }

    function markResolved(uint256 _id) external nonReentrant {
        require(_exists(_id), "Listing does not exist");
        require(listings[_id].creator == msg.sender, "Not listing creator");
        require(listings[_id].status == Status.InProgress, "Listing not in progress");

        listings[_id].status = Status.Resolved;

        // Update both profiles' completion stats
        (uint40 creatorCompleted, uint40 creatorCreated, uint40 creatorResponses,) = 
            profilesContract.getUserStats(msg.sender);
        (uint40 responderCompleted, uint40 responderCreated, uint40 responderResponses,) = 
            profilesContract.getUserStats(listings[_id].responder);

        profilesContract.updateProfileStats(
            msg.sender,
            creatorCompleted + 1,
            creatorCreated,
            creatorResponses
        );

        profilesContract.updateProfileStats(
            listings[_id].responder,
            responderCompleted + 1,
            responderCreated,
            responderResponses
        );

        emit ListingResolved(_id, block.timestamp);
    }

    function deactivateListing(uint256 _id) external nonReentrant {
        require(_exists(_id), "Listing does not exist");
        require(listings[_id].creator == msg.sender, "Not the listing creator");
        require(listings[_id].active, "Listing already inactive");

        listings[_id].active = false;
        listings[_id].status = Status.Expired;
        emit ListingDeactivated(_id, block.timestamp);
    }

    // ======== View Functions ========

    function getActiveListings() external view returns (Listing[] memory) {
        uint256 activeCount = 0;
        
        // Count active listings
        for (uint256 i = 1; i <= _listingIdCounter; i++) {
            if (listings[i].active) {
                activeCount++;
            }
        }

        // Create array of active listings
        Listing[] memory activeListings = new Listing[](activeCount);
        uint256 currentIndex = 0;
        
        for (uint256 i = 1; i <= _listingIdCounter; i++) {
            if (listings[i].active && !isExpired(i) && listings[i].status == Status.Open) {
                activeListings[currentIndex] = listings[i];
                currentIndex++;
            }
        }

        return activeListings;
    }

    function getUserListings(address _user) external view returns (Listing[] memory) {
        uint256[] memory userListingIds = userListings[_user];
        Listing[] memory userListingDetails = new Listing[](userListingIds.length);
        
        for (uint256 i = 0; i < userListingIds.length; i++) {
            userListingDetails[i] = listings[userListingIds[i]];
        }
        
        return userListingDetails;
    }

    function getListingsByStatus(Status _status) external view returns (Listing[] memory) {
        uint256 count = 0;
        for (uint256 i = 1; i <= _listingIdCounter; i++) {
            if (listings[i].status == _status) {
                count++;
            }
        }

        Listing[] memory filteredListings = new Listing[](count);
        uint256 currentIndex = 0;

        for (uint256 i = 1; i <= _listingIdCounter; i++) {
            if (listings[i].status == _status) {
                filteredListings[currentIndex] = listings[i];
                currentIndex++;
            }
        }

        return filteredListings;
    }

    function getCategories() external view returns (string[] memory) {
        return categories;
    }

    function getListing(uint256 listingId) public view returns (Listing memory) {
        return listings[listingId];
    }

    function isExpired(uint256 _id) public view returns (bool) {
        return block.timestamp >= listings[_id].timestamp + LISTING_DURATION;
    }

    function getListingsByExpertise(string calldata expertise) 
        external 
        view 
        returns (Listing[] memory) 
    {
        uint256 count = 0;
        for (uint256 i = 1; i <= _listingIdCounter; i++) {
            if (keccak256(bytes(listings[i].expertise)) == keccak256(bytes(expertise)) &&
                listings[i].active &&
                !isExpired(i)) {
                count++;
            }
        }

        Listing[] memory matchingListings = new Listing[](count);
        uint256 currentIndex = 0;
        
        for (uint256 i = 1; i <= _listingIdCounter; i++) {
            if (keccak256(bytes(listings[i].expertise)) == keccak256(bytes(expertise)) &&
                listings[i].active &&
                !isExpired(i)) {
                matchingListings[currentIndex] = listings[i];
                currentIndex++;
            }
        }

        return matchingListings;
    }

    // ======== Admin Functions ========

    function addCategory(string calldata _category) external onlyOwner {
        _addCategory(_category);
    }

    function removeCategory(string calldata _category) external onlyOwner {
        require(categoryExists[_category], "Category does not exist");
        categoryExists[_category] = false;
        
        // Remove from categories array
        for (uint256 i = 0; i < categories.length; i++) {
            if (keccak256(bytes(categories[i])) == keccak256(bytes(_category))) {
                categories[i] = categories[categories.length - 1];
                categories.pop();
                break;
            }
        }
        
        emit CategoryRemoved(_category);
    }

    // ======== Internal Functions ========

    function _exists(uint256 _id) internal view returns (bool) {
        return _id > 0 && _id <= _listingIdCounter;
    }

    function _addCategory(string memory _category) internal {
        require(!categoryExists[_category], "Category already exists");
        require(bytes(_category).length > 0, "Category cannot be empty");
        
        categories.push(_category);
        categoryExists[_category] = true;
        
        emit CategoryAdded(_category);
    }

    function _validateListingInputs(
        string calldata _title,
        string calldata _description,
        string calldata _category
    ) internal view {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_description).length > 0, "Description cannot be empty");
        require(categoryExists[_category], "Invalid category");
    }

    function _getNextListingId() internal returns (uint256) {
        _listingIdCounter++;
        return _listingIdCounter;
    }

    function _createListingStorage(
        uint256 newListingId,
        string calldata _title,
        string calldata _description,
        string calldata _category,
        bool _isProject,
        ExpertiseType _expertiseType,
        string calldata _expertise,
        string calldata _contactMethod
    ) internal {
        listings[newListingId] = Listing({
            id: newListingId,
            creator: msg.sender,
            title: _title,
            description: _description,
            category: _category,
            isProject: _isProject,
            expertiseType: _expertiseType,
            expertise: _expertise,
            contactMethod: _contactMethod,
            timestamp: block.timestamp,
            active: true,
            status: Status.Open,
            responder: address(0)
        });
    }

    function _updateUserListings(uint256 newListingId) internal {
        userListings[msg.sender].push(newListingId);
    }

    function _emitListingCreated(
        uint256 newListingId,
        string calldata _title,
        bool _isProject,
        string calldata _category
        ) internal {
        emit ListingCreated(
            newListingId,
            msg.sender,
            _title,
            _isProject,
            _category,
            block.timestamp
        );
    }
}