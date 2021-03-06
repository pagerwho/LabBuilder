$Global:ModuleRoot = Resolve-Path -Path "$($Script:MyInvocation.MyCommand.Path)\..\..\..\..\..\"
$OldPSModulePath = $env:PSModulePath
Push-Location
try
{
    Set-Location -Path $ModuleRoot

    if (Get-Module -Name LabBuilder -All)
    {
        Get-Module -Name LabBuilder -All | Remove-Module
    }

    Import-Module -Name (Join-Path -Path $Global:ModuleRoot -ChildPath 'src\LabBuilder.psd1') `
        -Force `
        -DisableNameChecking
    Import-Module -Name (Join-Path -Path $Global:ModuleRoot -ChildPath 'test\testhelper\testhelper.psm1') -Global

    $Global:TestConfigPath = Join-Path `
        -Path $Global:ModuleRoot `
        -ChildPath 'test\pestertestconfig'
    $Global:TestConfigOKPath = Join-Path `
        -Path $Global:TestConfigPath `
        -ChildPath 'PesterTestConfig.OK.xml'
    $Global:ArtifactPath = Join-Path `
        -Path $Global:ModuleRoot `
        -ChildPath 'test\artifacts'
    $Global:ExpectedContentPath = Join-Path `
        -Path $Global:TestConfigPath `
        -ChildPath 'expectedcontent'
    $null = New-Item `
        -Path $Global:ArtifactPath `
        -ItemType Directory `
        -Force `
        -ErrorAction SilentlyContinue

    InModuleScope LabBuilder {
        # Run tests assuming Build 10586 is installed
        $Script:CurrentBuild = 10586

        Describe '\lib\private\Vhd.ps1\InitializeBootVHD' {
            $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
            [array] $VMs = Get-LabVM -Lab $Lab
            $NanoServerPackagesFolder = Join-Path -Path $Lab.labbuilderconfig.settings.labpath -ChildPath 'NanoServerPackages'
            $ResourceMSUFile = Join-Path -Path $Lab.labbuilderconfig.settings.resourcepathfull -ChildPath "W2K12-KB3191565-x64.msu"

            Mock New-Item
            Mock Mount-WindowsImage
            Mock Dismount-WindowsImage
            Mock Add-WindowsPackage
            Mock Copy-Item
            Mock Remove-Item

            Context 'Valid Configuration Passed with Server VM and an invalid package' {
                It 'Throws a PackageNotFoundError exception' {
                    $VM = $VMs[0].Clone()
                    $VM.Packages = 'DoesNotExist'
                    $exceptionParameters = @{
                        errorId = 'PackageNotFoundError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.PackageNotFoundError `
                            -f 'DoesNotExist')
                    }
                    $Exception = Get-LabException @exceptionParameters
                    { InitializeBootVHD -Lab $Lab -VM $VM -VMBootDiskPath 'c:\Dummy\' } | Should -Throw $Exception
                }
                It 'Calls Mocked commands' {
                    Assert-MockCalled New-Item -Exactly 1
                    Assert-MockCalled Mount-WindowsImage -Exactly 1
                    Assert-MockCalled Dismount-WindowsImage -Exactly 1
                    Assert-MockCalled Add-WindowsPackage -Exactly 0
                    Assert-MockCalled Copy-Item -Exactly 0
                    Assert-MockCalled Remove-Item -Exactly 1
                }
            }

            Context 'When valid Configuration Passed with Server VM and one package' {
                Mock -CommandName Test-Path -ParameterFilter { $Path -eq $ResourceMSUFile } -MockWith { $true }

                It 'Does Not Throw Exception' {
                    $VM = $VMs[0].Clone()
                    $VM.Packages = 'WMF5.1-WS2012R2-W81'
                    { InitializeBootVHD -Lab $Lab -VM $VM -VMBootDiskPath 'c:\Dummy\' } | Should -Not -Throw
                }

                It 'Calls Mocked commands' {
                    Assert-MockCalled New-Item -Exactly 4
                    Assert-MockCalled Mount-WindowsImage -Exactly 1
                    Assert-MockCalled Dismount-WindowsImage -Exactly 1
                    Assert-MockCalled Add-WindowsPackage -Exactly 1
                    Assert-MockCalled Copy-Item -Exactly 4
                    Assert-MockCalled Remove-Item -Exactly 1
                }
            }

            Context 'When valid Configuration Passed with Server VM and one package but MSU does not exist' {
                Mock -CommandName Test-Path -ParameterFilter { $Path -eq $ResourceMSUFile } -MockWith { $false }

                It 'Throws a PackageMSUNotFoundError exception' {
                    $VM = $VMs[0].Clone()
                    $VM.Packages = 'WMF5.1-WS2012R2-W81'
                    $exceptionParameters = @{
                        errorId = 'PackageMSUNotFoundError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.PackageMSUNotFoundError `
                            -f 'WMF5.1-WS2012R2-W81',$ResourceMSUFile)
                    }
                    $exception = Get-LabException @exceptionParameters
                    { InitializeBootVHD -Lab $Lab -VM $VM -VMBootDiskPath 'c:\Dummy\' } | Should -Throw $exception
                }
                It 'Calls Mocked commands' {
                    Assert-MockCalled New-Item -Exactly 1
                    Assert-MockCalled Mount-WindowsImage -Exactly 1
                    Assert-MockCalled Dismount-WindowsImage -Exactly 1
                    Assert-MockCalled Add-WindowsPackage -Exactly 0
                    Assert-MockCalled Copy-Item -Exactly 0
                    Assert-MockCalled Remove-Item -Exactly 1
                    Assert-MockCalled Test-Path -Exactly 1
                }
            }
            Context 'Valid Configuration Passed with Nano Server VM and no packages' {
                Mock Test-Path -ParameterFilter { $Path -eq $NanoServerPackagesFolder } -MockWith { $true }
                Mock Test-Path -ParameterFilter { $Path -like "$NanoServerPackagesFolder\*.cab" } -MockWith { $true }
                It 'Does Not Throw Exception' {
                    $VM = $VMs[0].Clone()
                    $VM.Packages = ''
                    $VM.OSType = [LabOStype]::Nano
                    { InitializeBootVHD -Lab $Lab -VM $VM -VMBootDiskPath 'c:\Dummy\' } | Should -Not -Throw
                }
                It 'Calls Mocked commands' {
                    Assert-MockCalled New-Item -Exactly 4
                    Assert-MockCalled Mount-WindowsImage -Exactly 1
                    Assert-MockCalled Dismount-WindowsImage -Exactly 1
                    Assert-MockCalled Add-WindowsPackage -Exactly 2
                    Assert-MockCalled Copy-Item -Exactly 3
                    Assert-MockCalled Remove-Item -Exactly 1
                    Assert-MockCalled Test-Path -Exactly 3
                }
            }
            Context 'Valid Configuration Passed with Nano Server VM and two packages' {
                Mock Test-Path -ParameterFilter { $Path -eq $NanoServerPackagesFolder } -MockWith { $true }
                Mock Test-Path -ParameterFilter { $Path -like "$NanoServerPackagesFolder\*.cab" } -MockWith { $true }
                It 'Does Not Throw Exception' {
                    $VM = $VMs[0].Clone()
                    $VM.OSType = [LabOStype]::Nano
                    $VM.Packages = 'Microsoft-NanoServer-Containers-Package.cab,Microsoft-NanoServer-Guest-Package.cab'
                    { InitializeBootVHD -Lab $Lab -VM $VM -VMBootDiskPath 'c:\Dummy\' } | Should -Not -Throw
                }
                It 'Calls Mocked commands' {
                    Assert-MockCalled New-Item -Exactly 4
                    Assert-MockCalled Mount-WindowsImage -Exactly 1
                    Assert-MockCalled Dismount-WindowsImage -Exactly 1
                    Assert-MockCalled Add-WindowsPackage -Exactly 6
                    Assert-MockCalled Copy-Item -Exactly 3
                    Assert-MockCalled Remove-Item -Exactly 1
                    Assert-MockCalled Test-Path -Exactly 7
                }
            }
            Context 'Valid Configuration Passed with Nano Server VM and two packages and an MSU' {
                Mock Test-Path -ParameterFilter { $Path -eq $NanoServerPackagesFolder } -MockWith { $true }
                Mock Test-Path -ParameterFilter { $Path -like "$NanoServerPackagesFolder\*.cab" } -MockWith { $true }
                Mock Test-Path -ParameterFilter { $Path -eq $ResourceMSUFile } -MockWith { $true }

                It 'Does Not Throw Exception' {
                    $VM = $VMs[0].Clone()
                    $VM.OSType = [LabOStype]::Nano
                    $VM.Packages = 'Microsoft-NanoServer-Containers-Package.cab,Microsoft-NanoServer-Guest-Package.cab,WMF5.1-WS2012R2-W81'
                    { InitializeBootVHD -Lab $Lab -VM $VM -VMBootDiskPath 'c:\Dummy\' } | Should -Not -Throw
                }
                It 'Calls Mocked commands' {
                    Assert-MockCalled New-Item -Exactly 4
                    Assert-MockCalled Mount-WindowsImage -Exactly 1
                    Assert-MockCalled Dismount-WindowsImage -Exactly 1
                    Assert-MockCalled Add-WindowsPackage -Exactly 7
                    Assert-MockCalled Copy-Item -Exactly 3
                    Assert-MockCalled Remove-Item -Exactly 1
                    Assert-MockCalled Test-Path -Exactly 8
                }
            }
            Context 'Valid Configuration Passed with Nano Server VM and two packages but NanoServerPackages folder missing' {
                Mock Test-Path -ParameterFilter { $Path -eq $NanoServerPackagesFolder } -MockWith { $false }
                It 'Throws a NanoServerPackagesFolderMissingError exception' {
                    $VM = $VMs[0].Clone()
                    $VM.OSType = [LabOStype]::Nano
                    $VM.Packages = 'Microsoft-NanoServer-Containers-Package.cab,Microsoft-NanoServer-Guest-Package.cab'
                    $exceptionParameters = @{
                        errorId = 'NanoServerPackagesFolderMissingError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.NanoServerPackagesFolderMissingError `
                            -f $NanoServerPackagesFolder)
                    }
                    $Exception = Get-LabException @exceptionParameters
                    { InitializeBootVHD -Lab $Lab -VM $VM -VMBootDiskPath 'c:\Dummy\' } | Should -Throw $Exception
                }
                It 'Calls Mocked commands' {
                    Assert-MockCalled New-Item -Exactly 1
                    Assert-MockCalled Mount-WindowsImage -Exactly 1
                    Assert-MockCalled Dismount-WindowsImage -Exactly 1
                    Assert-MockCalled Add-WindowsPackage -Exactly 0
                    Assert-MockCalled Copy-Item -Exactly 0
                    Assert-MockCalled Remove-Item -Exactly 1
                    Assert-MockCalled Test-Path -Exactly 1
                }
            }
            Context 'Valid Configuration Passed' {
                Mock Test-Path -ParameterFilter { $Path -eq $ResourceMSUFile } -MockWith { $true }
                It 'Does Not Throw Exception' {
                    $VM = $VMs[0].Clone()
                    { InitializeBootVHD -Lab $Lab -VM $VM -VMBootDiskPath 'c:\Dummy\' } | Should -Not -Throw
                }
                It 'Calls Mocked commands' {
                    Assert-MockCalled New-Item -Exactly 4
                    Assert-MockCalled Mount-WindowsImage -Exactly 1
                    Assert-MockCalled Dismount-WindowsImage -Exactly 1
                    Assert-MockCalled Add-WindowsPackage -Exactly 1
                    Assert-MockCalled Copy-Item -Exactly 4
                    Assert-MockCalled Remove-Item -Exactly 1
                    Assert-MockCalled Test-Path -Exactly 1
                }
            }
        }



        Describe '\lib\private\Vhd.ps1\InitializeVHD' {
            # Mock functions
            function Get-VHD {}
            function Mount-VHD {}

            $VHD = @{
                Path = 'c:\DataVHDx.vhdx'
            }
            $VHDCreate = @{
                Path = $VHD.Path
                PartitionStyle = 'GPT'
                FileSystem = 'NTFS'
            }
            $VHDLabel = @{
                Path = $VHD.Path
                PartitionStyle = 'GPT'
                FileSystem = 'NTFS'
                FileSystemLabel = 'New'
            }
            $Partition1 = New-CimInstance `
                    -ClassName 'MSFT_Partition' `
                    -Namespace ROOT/Microsoft/Windows/Storage `
                    -ClientOnly `
                    -Property @{
                        DiskNumber = 9
                        Type = 'Basic'
                        PartitionNumber = 1
                    }
            $Partition2 = New-CimInstance `
                    -ClassName 'MSFT_Partition' `
                    -Namespace ROOT/Microsoft/Windows/Storage `
                    -ClientOnly `
                    -Property @{
                        DiskNumber = 9
                        Type = 'Basic'
                        PartitionNumber = 2
                    }
            $Volume1 = New-CimInstance `
                    -ClassName 'MSFT_Volume' `
                    -Namespace ROOT/Microsoft/Windows/Storage `
                    -ClientOnly `
                    -Property @{
                        FileSystem = 'FAT32'
                        FileSystemLabel = 'Volume1'
                    }
            $Volume2 = New-CimInstance `
                    -ClassName 'MSFT_Volume' `
                    -Namespace ROOT/Microsoft/Windows/Storage `
                    -ClientOnly `
                    -Property @{
                        FileSystem = 'NTFS'
                        FileSystemLabel = 'Volume2'
                    }
            $NewVolume = New-CimInstance `
                    -ClassName 'MSFT_Volume' `
                    -Namespace ROOT/Microsoft/Windows/Storage `
                    -ClientOnly `
                    -Property @{
                        FileSystem = $VHDLabel.FileSystem
                        FileSystemLabel = $VHDLabel.FileSystemLabel
                    }
            $RenamedVolume = New-CimInstance `
                    -ClassName 'MSFT_Volume' `
                    -Namespace ROOT/Microsoft/Windows/Storage `
                    -ClientOnly `
                    -Property @{
                        FileSystem = $VHDLabel.FileSystem
                        FileSystemLabel = 'Different'
                    }
            $UnformattedVolume = New-CimInstance `
                    -ClassName 'MSFT_Volume' `
                    -Namespace ROOT/Microsoft/Windows/Storage `
                    -ClientOnly `
                    -Property @{
                        FileSystem = ''
                        FileSystemLabel = $VHDLabel.FileSystemLabel
                    }

            Mock Test-Path -MockWith { $false }
            Mock Get-VHD
            Mock Mount-VHD
            Mock Get-Disk
            Mock Initialize-Disk
            Mock Get-Partition
            Mock New-Partition
            Mock Get-Volume
            Mock Format-Volume
            Mock Set-Volume
            Mock Set-Partition
            Mock Add-PartitionAccessPath
            Context 'VHDx file does not exist' {
                It 'Throws a FileNotFoundError Exception' {
                    $Splat = $VHD.Clone()
                    $exceptionParameters = @{
                        errorId = 'FileNotFoundError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.FileNotFoundError `
                            -f "VHD",$Splat.Path)
                    }
                    $Exception = Get-LabException @exceptionParameters

                    { InitializeVHD @Splat } | Should -Throw $Exception
                }
                It 'Calls appropriate mocks' {
                    Assert-MockCalled Get-VHD -Exactly 0
                    Assert-MockCalled Mount-VHD -Exactly 0
                    Assert-MockCalled Get-Disk -Exactly 0
                    Assert-MockCalled Initialize-Disk -Exactly 0
                    Assert-MockCalled Get-Partition -Exactly 0
                    Assert-MockCalled New-Partition -Exactly 0
                    Assert-MockCalled Get-Volume -Exactly 0
                    Assert-MockCalled Format-Volume -Exactly 0
                    Assert-MockCalled Set-Volume -Exactly 0
                    Assert-MockCalled Set-Partition -Exactly 0
                    Assert-MockCalled Add-PartitionAccessPath -Exactly 0
                }
            }
            Mock Test-Path -MockWith { $true }
            Mock Get-VHD -MockWith { @{ Attached = $false; DiskNumber = 9 } }
            Mock Get-Disk -MockWith { @{ PartitionStyle = 'RAW' } }
            Context 'VHDx file exists is not mounted, is not initialized and partition style is not passed' {
                It 'Throws a InitializeVHDNotInitializedError Exception' {
                    $Splat = $VHD.Clone()
                    $exceptionParameters = @{
                        errorId = 'InitializeVHDNotInitializedError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.InitializeVHDNotInitializedError `
                            -f$Splat.Path)
                    }
                    $Exception = Get-LabException @exceptionParameters

                    { InitializeVHD @Splat } | Should -Throw $Exception
                }
                It 'Calls appropriate mocks' {
                    Assert-MockCalled Get-VHD -Exactly 2
                    Assert-MockCalled Mount-VHD -Exactly 1
                    Assert-MockCalled Get-Disk -Exactly 1
                    Assert-MockCalled Initialize-Disk -Exactly 0
                    Assert-MockCalled Get-Partition -Exactly 0
                    Assert-MockCalled New-Partition -Exactly 0
                    Assert-MockCalled Get-Volume -Exactly 0
                    Assert-MockCalled Format-Volume -Exactly 0
                    Assert-MockCalled Set-Volume -Exactly 0
                    Assert-MockCalled Set-Partition -Exactly 0
                    Assert-MockCalled Add-PartitionAccessPath -Exactly 0
                }
            }
            Mock Get-Disk -MockWith { @{ PartitionStyle = $VHDLabel.PartitionStyle } }
            Mock Get-Partition -MockWith { @( $Partition1 ) }
            Mock Get-Volume -MockWith { $NewVolume } -ParameterFilter { $Partition -eq $Partition1 }
            Mock Get-Volume -MockWith { $Volume2 } -ParameterFilter { $Partition -eq $Partition2 }
            Mock Set-Volume -MockWith { $RenamedVolume }
            Context 'VHDx file exists is not mounted, is initialized, has 1 partition the volume FileSystemLabel is different' {
                It 'Returns Expected Volume' {
                    $Splat = $VHDLabel.Clone()
                    $Splat.FileSystemLabel = 'Different'

                    InitializeVHD @Splat | Should -Be $RenamedVolume
                }
                It 'Calls appropriate mocks' {
                    Assert-MockCalled Get-VHD -Exactly 2
                    Assert-MockCalled Mount-VHD -Exactly 1
                    Assert-MockCalled Get-Disk -Exactly 1
                    Assert-MockCalled Initialize-Disk -Exactly 0
                    Assert-MockCalled Get-Partition -Exactly 1
                    Assert-MockCalled New-Partition -Exactly 0
                    Assert-MockCalled Get-Volume -Exactly 2
                    Assert-MockCalled Format-Volume -Exactly 0
                    Assert-MockCalled Set-Volume -Exactly 1
                    Assert-MockCalled Set-Partition -Exactly 0
                    Assert-MockCalled Add-PartitionAccessPath -Exactly 0
                }
            }
            Mock Get-Partition -MockWith { @( $Partition1,$Partition2 ) }
            Mock Get-Volume -MockWith { $Volume1 } -ParameterFilter { $Partition -eq $Partition1 }
            Mock Get-Volume -MockWith { $Volume2 } -ParameterFilter { $Partition -eq $Partition2 }
            Context 'VHDx file exists is not mounted, is initialized, has 2 partitions' {
                It 'Returns Expected Volume' {
                    $Splat = $VHDLabel.Clone()
                    $Splat.FileSystemLabel = 'Different'

                    InitializeVHD @Splat | Should -Be $RenamedVolume
                }
                It 'Calls appropriate mocks' {
                    Assert-MockCalled Get-VHD -Exactly 2
                    Assert-MockCalled Mount-VHD -Exactly 1
                    Assert-MockCalled Get-Disk -Exactly 1
                    Assert-MockCalled Initialize-Disk -Exactly 0
                    Assert-MockCalled Get-Partition -Exactly 1
                    Assert-MockCalled New-Partition -Exactly 0
                    Assert-MockCalled Get-Volume -Exactly 3
                    Assert-MockCalled Format-Volume -Exactly 0
                    Assert-MockCalled Set-Volume -Exactly 1
                    Assert-MockCalled Set-Partition -Exactly 0
                    Assert-MockCalled Add-PartitionAccessPath -Exactly 0
                }
            }
            Mock Get-Disk -MockWith { @{ PartitionStyle = 'RAW' } }
            Mock Get-Partition
            Mock New-Partition -MockWith { @( $Partition1 ) }
            Mock Get-Volume -MockWith { $UnformattedVolume } -ParameterFilter { $Partition -eq $Partition1 }
            Mock Format-Volume -MockWith { @( $NewVolume ) }
            Context 'VHDx file exists is not mounted, is not initialized and label is passed' {
                It 'Returns Expected Volume' {
                    $Splat = $VHDLabel.Clone()

                    InitializeVHD @Splat | Should -Be $NewVolume
                }
                It 'Calls appropriate mocks' {
                    Assert-MockCalled Get-VHD -Exactly 2
                    Assert-MockCalled Mount-VHD -Exactly 1
                    Assert-MockCalled Get-Disk -Exactly 1
                    Assert-MockCalled Initialize-Disk -Exactly 1
                    Assert-MockCalled Get-Partition -Exactly 1
                    Assert-MockCalled New-Partition -Exactly 1
                    Assert-MockCalled Get-Volume -Exactly 2
                    Assert-MockCalled Format-Volume -Exactly 1
                    Assert-MockCalled Set-Volume -Exactly 0
                    Assert-MockCalled Set-Partition -Exactly 0
                    Assert-MockCalled Add-PartitionAccessPath -Exactly 0
                }
            }
            Context 'VHDx file exists is not mounted, is not initialized and label and DriveLetter passed' {
                It 'Returns Expected Volume' {
                    $Splat = $VHDLabel.Clone()
                    $Splat.DriveLetter = 'X'

                    InitializeVHD @Splat | Should -Be $UnformattedVolume # would be NewVolume but Get-Volume is mocked to this.
                }
                It 'Calls appropriate mocks' {
                    Assert-MockCalled Get-VHD -Exactly 2
                    Assert-MockCalled Mount-VHD -Exactly 1
                    Assert-MockCalled Get-Disk -Exactly 1
                    Assert-MockCalled Initialize-Disk -Exactly 1
                    Assert-MockCalled Get-Partition -Exactly 1
                    Assert-MockCalled New-Partition -Exactly 1
                    Assert-MockCalled Get-Volume -Exactly 3
                    Assert-MockCalled Format-Volume -Exactly 1
                    Assert-MockCalled Set-Volume -Exactly 0
                    Assert-MockCalled Set-Partition -Exactly 1
                    Assert-MockCalled Add-PartitionAccessPath -Exactly 0
                }
            }
            Context 'VHDx file exists is not mounted, is not initialized and label and AccessPath passed' {
                It 'Returns Expected Volume' {
                    $Splat = $VHDLabel.Clone()
                    $Splat.AccessPath = 'c:\Exists'

                    InitializeVHD @Splat | Should -Be $NewVolume
                }
                It 'Calls appropriate mocks' {
                    Assert-MockCalled Get-VHD -Exactly 2
                    Assert-MockCalled Mount-VHD -Exactly 1
                    Assert-MockCalled Get-Disk -Exactly 1
                    Assert-MockCalled Initialize-Disk -Exactly 1
                    Assert-MockCalled Get-Partition -Exactly 1
                    Assert-MockCalled New-Partition -Exactly 1
                    Assert-MockCalled Get-Volume -Exactly 2
                    Assert-MockCalled Format-Volume -Exactly 1
                    Assert-MockCalled Set-Volume -Exactly 0
                    Assert-MockCalled Set-Partition -Exactly 0
                    Assert-MockCalled Add-PartitionAccessPath -Exactly 1
                }
            }
            Mock Test-Path -ParameterFilter { $Path -eq 'c:\DoesNotExist' } -MockWith { $false }
            Context 'VHDx file exists is not mounted, is not initialized and invalid AccessPath passed' {
                It 'Throws a InitializeVHDAccessPathNotFoundError Exception' {
                    $Splat = $VHDLabel.Clone()
                    $Splat.AccessPath = 'c:\DoesNotExist'

                    $exceptionParameters = @{
                        errorId = 'InitializeVHDAccessPathNotFoundError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.InitializeVHDAccessPathNotFoundError `
                            -f$Splat.Path,'c:\DoesNotExist')
                    }
                    $Exception = Get-LabException @exceptionParameters

                    { InitializeVHD @Splat } | Should -Throw $Exception
                }
                It 'Calls appropriate mocks' {
                    Assert-MockCalled Get-VHD -Exactly 2
                    Assert-MockCalled Mount-VHD -Exactly 1
                    Assert-MockCalled Get-Disk -Exactly 1
                    Assert-MockCalled Initialize-Disk -Exactly 1
                    Assert-MockCalled Get-Partition -Exactly 1
                    Assert-MockCalled New-Partition -Exactly 1
                    Assert-MockCalled Get-Volume -Exactly 2
                    Assert-MockCalled Format-Volume -Exactly 1
                    Assert-MockCalled Set-Volume -Exactly 0
                    Assert-MockCalled Set-Partition -Exactly 0
                    Assert-MockCalled Add-PartitionAccessPath -Exactly 0
                }
            }
        }
    }
}
catch
{
    throw $_
}
finally
{
    Pop-Location
    $env:PSModulePath = $OldPSModulePath
}
