## 📊 System Architecture

Program Overview

## Table 1. Patch_history

The main_1_history.ps1 script is designed to automate the process of retrieving and processing email messages related to patch history from a Microsoft Graph Mail account. The script performs the following key functions:

Environment Setup: It imports necessary modules and sets up the environment, including defining the maximum attachment size and sender information.

Connection to Microsoft Graph: The script establishes a connection to Microsoft Graph using certificate-based authentication.

Email Retrieval: It retrieves email messages from the user's inbox that match specific criteria, such as being sent from a designated email address and containing the subject "history".

Attachment Processing: The script checks for attachments in the retrieved messages, ensuring that they meet size constraints. It processes the content of the attachments, specifically looking for CSV files.

Data Normalization: The script normalizes the data by cleaning up column names and filtering rows based on specific conditions (e.g., installation status).

Encryption: It encrypts sensitive data using AES encryption, ensuring that the data is securely handled before transmission.

Data Transmission: Finally, the processed data is sent to a specified server endpoint in JSON format, allowing for further analysis or storage.

Error Handling: The script includes error handling to manage exceptions and ensure that the process completes gracefully.

This script is essential for maintaining an organized record of patch history and automating the reporting process, thereby enhancing operational efficiency.

<table align="center">
  <tr>
    <td align="center">
      <img src="./table1_history/table1-history-patch.jpg" width="240"><br>
      <b>Table 1<br>Patch History</b>
    </td>
    <td align="center">
      <img src="./table2_available_patch/table2-available-patch.jpg" width="240"><br>
      <b>Table 2<br>Available Patches</b>
    </td>
    <td align="center">
      <img src="./table3_Group_patch_computer/table3-group-patch-computer.jpg" width="240"><br>
      <b>Table 3<br>Patch Grouping</b>
    </td>
  </tr>
</table>
