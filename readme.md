# Decentralized Lottery

This project is a decentralized lottery system built on Ethereum, featuring a smart contract for lottery management and a backend event listener.

## Smart Contract

The lottery smart contract is responsible for handling the lottery logic, including ticket purchases, random winner selection, and prize distribution. It is developed using Foundry.

## Features:

- Users can enter the lottery by purchasing a ticket.
- A Chainlink VRF (or similar mechanism) ensures fair and random winner selection.
- The contract stores lottery rounds and manages payouts securely.

## Event Listener

The backend listener, written in Go, listens for lottery events emitted by the smart contract, such as new entries, winner announcements, and payouts.

## Features:

- Listens to blockchain events related to the lottery contract.
- Processes winner selection and logs event details.
- Can trigger notifications or integrate with external services.

## Contributing

Feel free to fork the repository, open issues, and submit pull requests to improve the project.

## License

This project is open-source and available under the MIT License.
