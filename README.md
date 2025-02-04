# Cabo - Real-Time Multiplayer Card Game Backend

## Overview  
Cabo is a memory-based multiplayer card game built with a Rails backend that powers real-time gameplay for both web (React) and mobile (React Native) clients. The game leverages WebSockets, event-driven architecture, and optimized API calls to ensure a smooth, lag-free experience with precise game state synchronization.

## Features  
✅ **Real-time Gameplay** – WebSockets ensure instant updates to all players  
✅ **Event-Driven Architecture** – Optimized with event machines for high consistency  
✅ **Concurrency & Locking** – Prevents race conditions and maintains fairness  
✅ **Multi-Platform Support** – Works seamlessly with React & React Native front-ends  

## Tech Stack  
- **Backend:** Ruby on Rails, WebSockets, EventMachine, Redis, Docker
- **Frontend Clients:** React, React Native (not included in this repo)  
- **Database:** MySQL or sqlite3
- **Hosting:** Local or Cloud (using Docker)  

## Setup Instructions  
### Prerequisites  
- Ruby 
- Rails 
- MySQL or sqlite3  
- Redis
- Docker
- React - Web or React Native - Mobile (frontend game) 