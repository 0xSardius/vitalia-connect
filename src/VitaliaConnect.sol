// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

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


    // ======== Type Definitions ========

    /// @dev Enum to define the type of expertise being offered/sought
    enum ExpertiseType { SEEKING, OFFERING }

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
    }

    // ======== Storage ========

    /// @dev Mapping from listing ID to Listing struct
    mapping(uint256 => Listing) public listings;
    
    /// @dev Mapping from address to array of listing IDs
    mapping(address => uint256[]) public userListings;

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

    // ======== Constructor ========

    constructor() Ownable(msg.sender) {
        // Initialize with default categories
        _addCategory("Biohacking");
        _addCategory("Longevity Research");
        _addCategory("Biotech");
        _addCategory("Community Building");
        _addCategory("Governance");
        _addCategory("Technology");
    }

    // ======== External Functions ========

    /**
     * @dev Creates a new listing
     * @param _title Title of the listing
     * @param _description Description of the listing
     * @param _category Category of the listing
     * @param _isProject Whether this is a project or opportunity
     * @param _expertiseType Type of expertise (offering/seeking)
     * @param _expertise Specific expertise details
     * @param _contactMethod Contact method for the listing
     */
    function createListing(
        string calldata _title,
        string calldata _description,
        string calldata _category,
        bool _isProject,
        ExpertiseType _expertiseType,
        string calldata _expertise,
        string calldata _contactMethod
    ) external nonReentrant returns (uint256) {
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
        return newListingId;
    }

    /**
     * @dev Updates an existing listing
     */
    function updateListing(
        uint256 _id,
        string calldata _title,
        string calldata _description,
        string calldata _category,
        ExpertiseType _expertiseType,
        string calldata _expertise,
        string calldata _contactMethod
    ) external nonReentrant {
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

    /**
     * @dev Deactivates a listing
     */
    function deactivateListing(uint256 _id) external nonReentrant {
        require(_exists(_id), "Listing does not exist");
        require(listings[_id].creator == msg.sender, "Not the listing creator");
        require(listings[_id].active, "Listing already inactive");

        listings[_id].active = false;
        emit ListingDeactivated(_id, block.timestamp);
    }

    // ======== View Functions ========

    /**
     * @dev Returns all active listings
     */
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
            if (listings[i].active) {
                activeListings[currentIndex] = listings[i];
                currentIndex++;
            }
        }

        return activeListings;
    }

    /**
     * @dev Returns listings for a specific user
     */
    function getUserListings(address _user) external view returns (Listing[] memory) {
        uint256[] memory userListingIds = userListings[_user];
        Listing[] memory userListingDetails = new Listing[](userListingIds.length);
        
        for (uint256 i = 0; i < userListingIds.length; i++) {
            userListingDetails[i] = listings[userListingIds[i]];
        }
        
        return userListingDetails;
    }

    /**
     * @dev Returns all available categories
     */
    function getCategories() external view returns (string[] memory) {
        return categories;
    }

    function getListing(uint256 listingId) public view returns (Listing memory) {
        return listings[listingId];
    }

    // ======== Admin Functions ========

    /**
     * @dev Adds a new category (admin only)
     */
    function addCategory(string calldata _category) external onlyOwner {
        _addCategory(_category);
    }

    /**
     * @dev Removes a category (admin only)
     */
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
            active: true
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