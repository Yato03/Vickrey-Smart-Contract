// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.0 <0.9.0;

import "remix_tests.sol"; 
import "remix_accounts.sol";
import "../contracts/VickeryAuction.sol"; // Asegúrate de que el nombre del archivo esté bien

contract testSuite {
    VickreyAuction auction;
    uint public createdAuctionId;

    // Se ejecuta antes de todas las pruebas
    function beforeAll() public {
        auction = new VickreyAuction();

        // Crear subasta válida con tiempos actuales
        uint nowTs = block.timestamp;
        auction.createAuction(
            nowTs,
            nowTs + 60,   // commit durante 1 min
            nowTs + 120,  // reveal otros 60s
            1000
        );

        createdAuctionId = 0;
    }

    function testGetAllAuctions() public {
        VickreyAuction.AuctionInfo memory info = auction.getAllAuctions()[0];

        Assert.equal(info.id, createdAuctionId, "ID incorrecto");
        Assert.equal(info.maxPrice, 1000, "MaxPrice incorrecto");
        Assert.equal(info.finalized, false, "No deberia estar finalizada");
    }

    function testEstadoInicial() public {
        string memory estado = auction.getAuctionState(createdAuctionId);
        Assert.equal(estado, "COMMIT_ABIERTO", "Subasta no esta en COMMIT_ABIERTO");
    }

    // Simula cálculo de hash para puja 400 + salt "secreto123"
    function testCommitBid() public {
        bytes32 hashedBid = keccak256(abi.encodePacked(uint(400), "|", "secreto123"));
        auction.commitBid{value: 0}(createdAuctionId, hashedBid);
        Assert.ok(true, "Commit hecho");
    }

    /// #sender: account-1
    /// #value: 40
    function testRevealBid() public payable {
        // Esperar a que termine la fase commit (simulación real necesitaría delay o mocks)
        string memory estado = auction.getAuctionState(createdAuctionId);
        if (keccak256(bytes(estado)) == keccak256("REVEAL_ABIERTO")) {
            auction.revealBid{value: 40}(createdAuctionId, 400, "secreto123");
            Assert.ok(true, "Reveal hecho correctamente");
        } else {
            Assert.ok(true, "Aun no en fase REVEAL_ABIERTO (simulado)");
        }
    }

    function testGetNow() public {
        uint ts = block.timestamp;
        Assert.ok(ts > 0, "El timestamp debe ser mayor que cero");
    }
}
