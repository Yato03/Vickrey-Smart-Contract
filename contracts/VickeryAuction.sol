// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract VickreyAuction {
    address public owner;
    uint public auctionCount = 0;

    constructor() {
        owner = msg.sender;
    }

    struct Auction {
        uint256 startTime;
        uint256 endCommit;
        uint256 endReveal;
        uint256 maxPrice;
        bool finalized;
        address payable winner;
        uint256 winningPrice;
        address[] bidders;
        mapping(address => bytes32) commitments;
        mapping(address => bool) hasBid;
        mapping(address => uint256) revealedBids;
        mapping(address => uint256) deposits;
    }

    mapping(uint => Auction) private auctions;

    modifier onlyOwner() {
        require(msg.sender == owner, "Solo el owner puede ejecutar esto");
        _;
    }

    modifier auctionExists(uint auctionId) {
        require(auctionId < auctionCount, "La subasta no existe");
        _;
    }

    event AuctionCreated(uint indexed auctionId);
    event BidCommitted(uint indexed auctionId, address indexed bidder);
    event BidRevealed(uint indexed auctionId, address indexed bidder, uint value);
    event AuctionFinalized(uint indexed auctionId, address winner, uint price);

    // -----------------------------------------
    // CREAR SUBASTA
    // -----------------------------------------
    function createAuction(
        uint256 startTime,
        uint256 endCommit,
        uint256 endReveal,
        uint256 maxPrice
    ) external onlyOwner {
        require(startTime < endCommit && endCommit < endReveal, "Fechas inconsistentes");
        require(maxPrice > 0, "Precio maximo debe ser mayor que cero");

        Auction storage a = auctions[auctionCount];
        a.startTime = startTime;
        a.endCommit = endCommit;
        a.endReveal = endReveal;
        a.maxPrice = maxPrice;

        emit AuctionCreated(auctionCount);
        auctionCount++;
    }

    // -----------------------------------------
    // COMPROMETER PUJA (fase 1)
    // -----------------------------------------
    function commitBid(uint auctionId, bytes32 hashedBid) external payable auctionExists(auctionId) {
        Auction storage a = auctions[auctionId];
        require(block.timestamp >= a.startTime && block.timestamp < a.endCommit, "Fuera de la fase de compromiso");
        require(!a.hasBid[msg.sender], "Ya has pujado");

        a.commitments[msg.sender] = hashedBid;
        a.hasBid[msg.sender] = true;
        a.bidders.push(msg.sender);

        emit BidCommitted(auctionId, msg.sender);
    }

    // -----------------------------------------
    // REVELAR PUJA (fase 2)
    // -----------------------------------------
    function revealBid(uint auctionId, uint256 value, string memory salt) external payable auctionExists(auctionId) {
        Auction storage a = auctions[auctionId];
        require(block.timestamp >= a.endCommit && block.timestamp < a.endReveal, "No es la fase de revelacion");
        require(a.hasBid[msg.sender], "No tienes puja previa");
        require(a.revealedBids[msg.sender] == 0, "Ya revelado");

        bytes32 expected = keccak256(abi.encodePacked(value, "|", salt));
        require(expected == a.commitments[msg.sender], "Hash incorrecto");
        require(value > 0 && value <= a.maxPrice, "Puja invalida");

        uint256 deposit = value / 10;
        require(msg.value == deposit, "Debes pagar el 10% de deposito");

        a.revealedBids[msg.sender] = value;
        a.deposits[msg.sender] = msg.value;

        emit BidRevealed(auctionId, msg.sender, value);
    }

    // -----------------------------------------
    // FINALIZAR SUBASTA
    // -----------------------------------------
    function finalizeAuction(uint auctionId) external onlyOwner auctionExists(auctionId) {
        Auction storage a = auctions[auctionId];
        require(block.timestamp >= a.endReveal, "Aun no ha finalizado la subasta");
        require(!a.finalized, "Ya finalizada");

        address payable lowestBidder;
        uint256 lowest = type(uint256).max;
        uint256 secondLowest = type(uint256).max;

        for (uint i = 0; i < a.bidders.length; i++) {
            address bidder = a.bidders[i];
            uint256 bid = a.revealedBids[bidder];

            if (bid > 0) {
                if (bid < lowest) {
                    secondLowest = lowest;
                    lowest = bid;
                    lowestBidder = payable(bidder);
                } else if (bid < secondLowest && bid != lowest) {
                    secondLowest = bid;
                }
            }
        }

        require(lowest < type(uint256).max, "No hay pujas reveladas");

        a.winner = lowestBidder;
        a.winningPrice = secondLowest == type(uint256).max ? lowest : secondLowest;
        a.finalized = true;

        emit AuctionFinalized(auctionId, lowestBidder, a.winningPrice);
    }

    // -----------------------------------------
    // RETIRAR DEPÓSITO
    // -----------------------------------------
    function withdraw(uint auctionId) external auctionExists(auctionId) {
        Auction storage a = auctions[auctionId];
        require(a.finalized, "Subasta no finalizada");

        uint256 amount = a.deposits[msg.sender];
        require(amount > 0, "Nada que retirar");

        // Si es ganador no puede retirar aquí
        require(msg.sender != a.winner, "Ganador no retira aqui");

        a.deposits[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
    }

    // -----------------------------------------
    // CONSULTAR GANADOR
    // -----------------------------------------
    function getWinner(uint auctionId) external view auctionExists(auctionId) returns (address, uint) {
        Auction storage a = auctions[auctionId];
        require(a.finalized, "Aun no finalizada");
        return (a.winner, a.winningPrice);
    }

    // -----------------------------------------
    // CONSULTAR SUBASTA
    // -----------------------------------------
    function getAuctionState(uint auctionId) public view auctionExists(auctionId) returns (string memory) {
        Auction storage a = auctions[auctionId];

        if (block.timestamp < a.startTime) {
            return "NO_INICIADA";
        } else if (block.timestamp >= a.startTime && block.timestamp < a.endCommit) {
            return "COMMIT_ABIERTO";
        } else if (block.timestamp >= a.endCommit && block.timestamp < a.endReveal) {
            return "REVEAL_ABIERTO";
        } else if (block.timestamp >= a.endReveal && !a.finalized) {
            return "ESPERANDO_FINALIZACION";
        } else if (a.finalized) {
            return "FINALIZADA";
        } else {
            return "INDEFINIDO";
        }
    }

    // -----------------------------------------
    // CONSULTAR SUBASTAS EXISTENTES
    // -----------------------------------------
    struct AuctionInfo {
        uint256 id;
        uint256 startTime;
        uint256 endCommit;
        uint256 endReveal;
        uint256 maxPrice;
        bool finalized;
    }

    function getAllAuctions() external view returns (AuctionInfo[] memory) {
        AuctionInfo[] memory result = new AuctionInfo[](auctionCount);

        for (uint i = 0; i < auctionCount; i++) {
            Auction storage a = auctions[i];
            result[i] = AuctionInfo({
                id: i,
                startTime: a.startTime,
                endCommit: a.endCommit,
                endReveal: a.endReveal,
                maxPrice: a.maxPrice,
                finalized: a.finalized
            });
        }

        return result;
    }
}
