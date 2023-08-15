# Add assemblies for WPF
Add-Type -AssemblyName PresentationFramework,System.Windows.Forms

# XAML for the window
[xml]$XAML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Change Password" Height="300" Width="350" ResizeMode="NoResize" WindowStartupLocation="CenterScreen">
    <Grid>
        <Label Content="Old Password:" HorizontalAlignment="Left" VerticalAlignment="Top" Margin="10,10,0,0"/>
        <PasswordBox x:Name="oldPassword" HorizontalAlignment="Left" VerticalAlignment="Top" Width="300" Margin="10,30,0,0"/>
        
        <Label Content="New Password:" HorizontalAlignment="Left" VerticalAlignment="Top" Margin="10,60,0,0"/>
        <PasswordBox x:Name="password1" HorizontalAlignment="Left" VerticalAlignment="Top" Width="300" Margin="10,80,0,0"/>
        
        <Label Content="Confirm Password:" HorizontalAlignment="Left" VerticalAlignment="Top" Margin="10,110,0,0"/>
        <PasswordBox x:Name="password2" HorizontalAlignment="Left" VerticalAlignment="Top" Width="300" Margin="10,130,0,0"/>

        <Button x:Name="changeButton" Content="Change Password" HorizontalAlignment="Center" VerticalAlignment="Top" Margin="0,170,0,0"/>
        <TextBlock x:Name="status" HorizontalAlignment="Center" VerticalAlignment="Top" Margin="0,210,0,0" TextWrapping="Wrap" Width="300"/>
    </Grid>
</Window>
"@

# Convert XAML to WPF objects
$reader = (New-Object System.Xml.XmlNodeReader $XAML)
$window = [System.Windows.Markup.XamlReader]::Load($reader)

# Get window elements for use
$oldPassword = $window.FindName("oldPassword")
$password1 = $window.FindName("password1")
$password2 = $window.FindName("password2")
$changeButton = $window.FindName("changeButton")
$status = $window.FindName("status")

# Define max password age manually
$maxPasswordAge = [TimeSpan]::FromDays(30)

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

if ($daysLeft -ge 0 -and $daysLeft -le 10) {
    # Function to change the password
    $changeButton.Add_Click({
        if ($password1.Password -eq $password2.Password) {
            # Prompt the user
            $result = [System.Windows.MessageBox]::Show("Are you sure you want to change your password? Your session will be logged off.", "Confirmation", [System.Windows.MessageBoxButton]::YesNo)
            
            if ($result -eq "Yes") {
                try {
                    # Attempt to change the password using the ChangePassword method
                    $user.ChangePassword($oldPassword.Password, $password1.Password)
                    $status.Text = "Password changed successfully!"
                    # Log off the user
                    Start-Sleep -Seconds 3
                    [System.Windows.Forms.Application]::Exit()
                    shutdown.exe /l
                } catch {
                    $status.Text = "Error while changing the password: $($_.Exception.Message)"
                }
            }
        } else {
            $status.Text = "Passwords do not match!"
        }
    })

    # Show the window
    $window.ShowDialog() | Out-Null
}
