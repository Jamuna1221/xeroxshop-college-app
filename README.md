# Smart Print & Xerox Management System

## Overview

Smart Print & Xerox Management System is a college-based application that allows students to upload documents, select print options, and send print requests directly to the campus print shop. The system reduces waiting time, improves efficiency, and provides real-time status updates.

---

## Features

### Student Module

* Register and login
* Upload documents (PDF, images)
* Select print options (copies, color, page range)
* Send print requests
* Track order status
* Receive notifications when prints are ready

### Print Shop Module

* View incoming print requests
* Download and print documents
* Update order status (Pending → Printing → Completed)

---

## Tech Stack

### Frontend

* Flutter

### Backend (Firebase)

* Firebase Authentication
* Cloud Firestore
* Firebase Storage
* Firebase Cloud Messaging

---

## Project Structure

smart-print-system/
│
├── frontend/        # Flutter application
├── backend/         # Firebase configuration
├── docs/            # Documentation
└── README.md

---

## Workflow

1. Student uploads document
2. File is stored in Firebase Storage
3. Order details are saved in Firestore
4. Print shop receives the request
5. Shop prints and updates status
6. Student receives notification

---

## Setup Instructions

### Clone Repository

git clone https://github.com/your-username/smart-print-system.git

### Navigate to Frontend

cd frontend

### Install Dependencies

flutter pub get

### Run Application

flutter run

---

## Future Enhancements

* Online payment integration
* Queue/token system
* QR-based pickup system
* Admin dashboard with analytics
* AI-based document preview

---

## Team

* Your Name (Team Lead)
* Member 2
* Member 3

---

## Conclusion

This project provides a practical and efficient solution for managing college print shop operations digitally, reducing manual effort and improving user experience.
