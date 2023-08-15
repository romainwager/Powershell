<#
.SYNOPSIS
A script to allow domain users to change their password through a graphical user interface (WPF).

.DESCRIPTION
This script provides a WPF-based graphical interface enabling users to change their domain password. 
It defines certain password requirements, such as minimum length and complexity. The interface prompts users 
for their current password, the desired new password, and a confirmation of the new password.

Upon user input, the script performs various validations:
- Checks if the password is nearing its expiry date, based on the `$passwordReminderDays` variable.
- Ensures the new password meets the defined minimum length.
- If complexity is required, it checks the new password for uppercase letters, lowercase letters, digits, and special characters.
- Verifies that the new password and its confirmation match.

If all checks are successful, the user is prompted to confirm their password change. Upon confirmation, the script 
attempts to change the password. If successful, the user is logged out of their session. If unsuccessful, an error message is displayed.

Throughout this process, status messages are displayed to the user in the graphical interface with appropriate coloring (red for errors, green for success).

.NOTES
File Name      : PasswordExpiryReminder.ps1
Author         : Romain Wager (HiveTech)

#>

# Add assemblies for WPF
Add-Type -AssemblyName PresentationFramework,System.Windows.Forms

# Variables for password requirements
$minPasswordLength = 8
$passwordComplexityRequired = $true
$passwordReminderDays = 10
$maxPasswordAge = [TimeSpan]::FromDays(30)

# XAML for the window
[xml]$XAML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Change Password" Height="350" Width="350" ResizeMode="NoResize" WindowStartupLocation="CenterScreen">
    <Grid>
        <Label x:Name="expiryLabel" Content="Your password will expire in X days. Please change it." HorizontalAlignment="Center" VerticalAlignment="Top" Margin="0,5,0,0"/>
        
        <Label Content="Old Password:" HorizontalAlignment="Left" VerticalAlignment="Top" Margin="10,40,0,0"/>
        <PasswordBox x:Name="oldPassword" HorizontalAlignment="Left" VerticalAlignment="Top" Width="300" Margin="10,60,0,0"/>
        
        <Label Content="New Password:" HorizontalAlignment="Left" VerticalAlignment="Top" Margin="10,90,0,0"/>
        <PasswordBox x:Name="password1" HorizontalAlignment="Left" VerticalAlignment="Top" Width="300" Margin="10,110,0,0"/>
        
        <Label Content="Confirm Password:" HorizontalAlignment="Left" VerticalAlignment="Top" Margin="10,140,0,0"/>
        <PasswordBox x:Name="password2" HorizontalAlignment="Left" VerticalAlignment="Top" Width="300" Margin="10,160,0,0"/>

        <Button x:Name="changeButton" Content="Change Password" HorizontalAlignment="Center" VerticalAlignment="Top" Margin="0,200,0,0"/>
        <TextBlock x:Name="status" HorizontalAlignment="Center" VerticalAlignment="Top" Margin="0,240,0,0" TextWrapping="Wrap" Width="300"/>
    </Grid>
</Window>
"@

# Convert XAML to WPF objects
$reader = (New-Object System.Xml.XmlNodeReader $XAML)
$window = [System.Windows.Markup.XamlReader]::Load($reader)

# Get window elements for use
$expiryLabel = $window.FindName("expiryLabel")
$oldPassword = $window.FindName("oldPassword")
$password1 = $window.FindName("password1")
$password2 = $window.FindName("password2")
$changeButton = $window.FindName("changeButton")
$status = $window.FindName("status")

# Retrieve user details
$username = [Environment]::UserName
$domain = [Environment]::UserDomainName

# Using System.DirectoryServices.AccountManagement to get the current user
Add-Type -AssemblyName System.DirectoryServices.AccountManagement
$pc = New-Object System.DirectoryServices.AccountManagement.PrincipalContext([System.DirectoryServices.AccountManagement.ContextType]::Domain, $domain)
$user = [System.DirectoryServices.AccountManagement.UserPrincipal]::FindByIdentity($pc, $username)

# Calculate expiration
$passwordLastSet = $user.LastPasswordSet
$expiresOn = $passwordLastSet + $maxPasswordAge
$daysLeft = ($expiresOn - (Get-Date)).Days

if ($daysLeft -ge 0 -and $daysLeft -le $passwordReminderDays) {

    # Function to change the password
    $changeButton.Add_Click({
        if ($password1.Password -eq $password2.Password) {

            if ($password1.Password.Length -lt $minPasswordLength) {
                $status.Foreground = "Red"
                $status.Text = "Password must be at least $minPasswordLength characters long."
                return
            }
        
            if ($passwordComplexityRequired) {
                if (-not ($password1.Password -cmatch "[A-Z]") -or 
                    -not ($password1.Password -cmatch "[a-z]") -or 
                    -not ($password1.Password -cmatch "[0-9]") -or 
                    -not ($password1.Password -cmatch "[\W_]")) {
                    $status.Foreground = "Red"
                    $status.Text = "Password must contain at least 1 uppercase letter, 1 lowercase letter, 1 digit, and 1 special character."
                    return
                }
            }
            
            # Prompt the user
            $result = [System.Windows.MessageBox]::Show("Are you sure you want to change your password? Your session will be logged off.", "Confirmation", [System.Windows.MessageBoxButton]::YesNo)
            
            if ($result -eq "Yes") {
                try {
                    # Attempt to change the password using the ChangePassword method
                    $user.ChangePassword($oldPassword.Password, $password1.Password)
                    $status.Foreground = "Green"
                    $status.Text = "Password changed successfully!"
                    # Log off the user
                    Start-Sleep -Seconds 3
                    [System.Windows.Forms.Application]::Exit()
                    shutdown.exe /l
                } catch {
                    $status.Foreground = "Red"
                    $status.Text = "Error while changing the password: $($_.Exception.Message)"
                }
            }
        } else {
            $status.Foreground = "Red"
            $status.Text = "Passwords do not match!"
        }
    })
    
    $expiryLabel.Content = "Your password will expire in $daysLeft days. Please change it."

    # Show the window
    $window.ShowDialog() | Out-Null
}
