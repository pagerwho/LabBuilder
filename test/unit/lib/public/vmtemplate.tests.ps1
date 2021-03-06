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

        Describe 'Get-LabVMTemplate' {
            # Mock functions
            function Get-VM {}
            function Get-VMHardDiskDrive {}

            Mock Get-VM

            Context 'Configuration passed with template missing Template Name.' {
                It 'Throws a EmptyTemplateNameError Exception' {
                    $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                    $Lab.labbuilderconfig.templates.template[0].RemoveAttribute('name')
                    $exceptionParameters = @{
                        errorId = 'EmptyTemplateNameError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.EmptyTemplateNameError)
                    }
                    $Exception = Get-LabException @exceptionParameters

                    { Get-LabVMTemplate -Lab $Lab } | Should -Throw $Exception
                }
            }

            Context 'Configuration passed with template with Source VHD set to relative non-existent file.' {
                It 'Throws a TemplateSourceVHDNotFoundError Exception' {
                    $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                    $Lab.labbuilderconfig.templates.template[0].sourcevhd = 'This File Doesnt Exist.vhdx'
                    $exceptionParameters = @{
                        errorId = 'TemplateSourceVHDNotFoundError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.TemplateSourceVHDNotFoundError `
                            -f $Lab.labbuilderconfig.templates.template[0].name,"$Global:TestConfigPath\This File Doesnt Exist.vhdx")
                    }
                    $Exception = Get-LabException @exceptionParameters

                    { Get-LabVMTemplate -Lab $Lab } | Should -Throw $Exception
                }
            }

            Context 'Configuration passed with template with Source VHD set to absolute non-existent file.' {
                It 'Throws a TemplateSourceVHDNotFoundError Exception' {
                    $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                    $Lab.labbuilderconfig.templates.template[0].sourcevhd = 'c:\This File Doesnt Exist.vhdx'
                    $exceptionParameters = @{
                        errorId = 'TemplateSourceVHDNotFoundError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.TemplateSourceVHDNotFoundError `
                            -f $Lab.labbuilderconfig.templates.template[0].name,"c:\This File Doesnt Exist.vhdx")
                    }
                    $Exception = Get-LabException @exceptionParameters

                    { Get-LabVMTemplate -Lab $Lab } | Should -Throw $Exception
                }
            }

            Context 'Configuration passed with template with Source VHD and Template VHD.' {
                It 'Throws a TemplateSourceVHDAndTemplateVHDConflictError Exception' {
                    $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                    $Lab.labbuilderconfig.templates.template[0].SetAttribute('templatevhd','Windows Server 2012 R2 Datacenter FULL')
                    $exceptionParameters = @{
                        errorId = 'TemplateSourceVHDAndTemplateVHDConflictError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.TemplateSourceVHDAndTemplateVHDConflictError `
                            -f $Lab.labbuilderconfig.templates.template[0].name)
                    }
                    $Exception = Get-LabException @exceptionParameters

                    { Get-LabVMTemplate -Lab $Lab } | Should -Throw $Exception
                }
            }

            Context 'Configuration passed with template with no Source VHD and no Template VHD.' {
                It 'Throws a TemplateSourceVHDandTemplateVHDMissingError Exception' {
                    $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                    $Lab.labbuilderconfig.templates.template[0].RemoveAttribute('sourcevhd')
                    $exceptionParameters = @{
                        errorId = 'TemplateSourceVHDandTemplateVHDMissingError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.TemplateSourceVHDandTemplateVHDMissingError `
                            -f $Lab.labbuilderconfig.templates.template[0].name)
                    }
                    $Exception = Get-LabException @exceptionParameters

                    { Get-LabVMTemplate -Lab $Lab } | Should -Throw $Exception
                }
            }

            Context 'Configuration passed with template with Template VHD that does not exist.' {
                It 'Throws a TemplateSourceVHDAndTemplateVHDConflictError Exception' {
                    $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                    $Lab.labbuilderconfig.templates.template[1].TemplateVHD='Template VHD Does Not Exist'
                    $exceptionParameters = @{
                        errorId = 'TemplateTemplateVHDNotFoundError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.TemplateTemplateVHDNotFoundError `
                            -f $Lab.labbuilderconfig.templates.template[1].name,'Template VHD Does Not Exist')
                    }
                    $Exception = Get-LabException @exceptionParameters

                    { Get-LabVMTemplate -Lab $Lab } | Should -Throw $Exception
                }
            }

            Context 'Valid configuration is passed but no templates found' {
                It 'Returns Template Object that matches Expected Object' {
                    $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                    [Array]$Templates = Get-LabVMTemplate -Lab $Lab
                    # Remove the SourceVHD values for any templates because they
                    # will usually be relative to the test folder and won't exist
                    foreach ($Template in $Templates)
                    {
                        $Template.SourceVHD = 'Intentionally Removed'
                    }
                    Set-Content -Path "$Global:ArtifactPath\ExpectedTemplates.json" -Value ($Templates | ConvertTo-Json -Depth 2)
                    $ExpectedTemplates = Get-Content -Path "$Global:ExpectedContentPath\ExpectedTemplates.json"
                    [System.String]::Compare((Get-Content -Path "$Global:ArtifactPath\ExpectedTemplates.json"),$ExpectedTemplates,$true) | Should -Be 0
                }

                It 'Calls Mocked commands' {
                    Assert-MockCalled Get-VM -Exactly 0
                }
            }

            Mock Get-VM -MockWith { @(
                    @{ name = 'Pester Windows Server 2012 R2 Datacenter Full' }
                    @{ name = 'Pester Windows Server 2012 R2 Datacenter Core' }
                    @{ name = 'Pester Windows 10 Enterprise' }
                ) }
            Mock Get-VMHardDiskDrive -ParameterFilter { $VMName -eq 'Pester Windows Server 2012 R2 Datacenter Full' } `
                -MockWith { @{ path = 'Pester Windows Server 2012 R2 Datacenter Full.vhdx' } }
            Mock Get-VMHardDiskDrive -ParameterFilter { $VMName -eq 'Pester Windows Server 2012 R2 Datacenter Core' } `
                -MockWith { @{ path = 'Pester Windows Server 2012 R2 Datacenter Core.vhdx' } }
            Mock Get-VMHardDiskDrive -ParameterFilter { $VMName -eq 'Pester Windows 10 Enterprise' } `
                -MockWith { @{ path = 'Pester Windows 10 Enterprise.vhdx' } }

            Context 'Valid configuration is passed with a Name filter set to matching VM' {
                It 'Returns a Single Template object' {
                    $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                    $Lab.labbuilderconfig.templates.SetAttribute('fromvm','Pester *')
                    [Array] $Templates = Get-LabVMTemplate `
                        -Lab $Lab `
                        -Name $Lab.labbuilderconfig.Templates.template[0].Name
                    $Templates.Count | Should -Be 1
                }
            }

            Context 'Valid configuration is passed with a Name filter set to non-matching VM' {
                It 'Returns no Template objects' {
                    $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                    $Lab.labbuilderconfig.templates.SetAttribute('fromvm','Pester *')
                    [Array] $Templates = Get-LabVMTemplate `
                        -Lab $Lab `
                        -Name 'Does Not Exist'
                    $Templates.Count | Should -Be 0
                }
            }

            Context 'Valid configuration is passed and some templates are found' {
                It 'Returns Template Object that matches Expected Object' {
                    $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
                    $Lab.labbuilderconfig.templates.SetAttribute('fromvm','Pester *')
                    [Array]$Templates = Get-LabVMTemplate -Lab $Lab
                    # Remove the SourceVHD values for any templates because they
                    # will usually be relative to the test folder and won't exist
                    foreach ($Template in $Templates)
                    {
                        $Template.SourceVHD = 'Intentionally Removed'
                    }
                    Set-Content -Path "$Global:ArtifactPath\ExpectedTemplates.FromVM.json" -Value ($Templates | ConvertTo-Json -Depth 2)
                    $ExpectedTemplates = Get-Content -Path "$Global:ExpectedContentPath\ExpectedTemplates.FromVM.json"
                    [System.String]::Compare((Get-Content -Path "$Global:ArtifactPath\ExpectedTemplates.FromVM.json"),$ExpectedTemplates,$true) | Should -Be 0
                }

                It 'Calls Mocked commands' {
                    Assert-MockCalled Get-VM -Exactly 1
                    Assert-MockCalled Get-VMHardDiskDrive -Exactly 0
                }
            }
        }



        Describe 'Initialize-LabVMTemplate' {
            # Mock functions
            function Optimize-VHD {}
            function Get-VM {}

            $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
            [array] $VMTemplates = Get-LabVMTemplate -Lab $Lab
            [Int32] $TemplateCount = $Lab.labbuilderconfig.templates.template.count
            $ResourceWMFMSUFile = Join-Path -Path $Lab.labbuilderconfig.settings.resourcepathfull -ChildPath "W2K12-KB3191565-x64.msu"
            $ResourceRSATMSUFile = Join-Path -Path $Lab.labbuilderconfig.settings.resourcepathfull -ChildPath "WindowsTH-KB2693643-x64.msu"

            Mock Copy-Item
            Mock Set-ItemProperty -ParameterFilter { ($Name -eq 'IsReadOnly') -and ($Value -eq $true) }
            Mock Set-ItemProperty -ParameterFilter { ($Name -eq 'IsReadOnly') -and ($Value -eq $false) }
            Mock Test-Path -ParameterFilter { $Path -eq 'This File Doesnt Exist.vhdx' } -MockWith { $false }
            Mock Optimize-VHD
            Mock Get-VM
            Mock New-Item
            Mock Mount-WindowsImage
            Mock Add-WindowsPackage
            Mock Dismount-WindowsImage
            Mock Remove-Item

            Context 'When called with valid template array with non-existent VHD source file' {
                $Template = [LabVMTemplate]::New('Bad VHD')
                $Template.ParentVHD = 'This File Doesnt Exist.vhdx'
                $Template.SourceVHD = 'This File Doesnt Exist.vhdx'
                [LabVMTemplate[]] $Templates = @( $Template )

                It 'Should throw a TemplateSourceVHDNotFoundError Exception' {
                    $exceptionParameters = @{
                        errorId = 'TemplateSourceVHDNotFoundError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.TemplateSourceVHDNotFoundError `
                            -f $Template.Name,$Template.SourceVHD)
                    }
                    $Exception = Get-LabException @exceptionParameters

                    { Initialize-LabVMTemplate -Lab $Lab -VMTemplates $Templates } | Should -Throw $Exception
                }

                It 'Should call expected mocks' {
                    Assert-MockCalled Copy-Item -Exactly 0
                    Assert-MockCalled Set-ItemProperty -Exactly 0 -ParameterFilter { ($Name -eq 'IsReadOnly') -and ($Value -eq $true) }
                    Assert-MockCalled Set-ItemProperty -Exactly 0 -ParameterFilter { ($Name -eq 'IsReadOnly') -and ($Value -eq $false) }
                    Assert-MockCalled Optimize-VHD -Exactly 0
                    Assert-MockCalled New-Item -Exactly 0
                    Assert-MockCalled Mount-WindowsImage -Exactly 0
                    Assert-MockCalled Add-WindowsPackage -Exactly 0
                    Assert-MockCalled Dismount-WindowsImage -Exactly 0
                    Assert-MockCalled Remove-Item -Exactly 0
                }
            }

            Context 'Valid configuration is passed' {
                Mock Test-Path -ParameterFilter { $Path -eq $ResourceWMFMSUFile } -MockWith { $true }
                Mock Test-Path -ParameterFilter { $Path -eq $ResourceRSATMSUFile } -MockWith { $true }

                It 'Does not throw an Exception' {
                    { Initialize-LabVMTemplate -Lab $Lab -VMTemplates $VMTemplates } | Should -Not -Throw
                }

                It 'Calls Mocked commands' {
                    Assert-MockCalled Copy-Item -Exactly ($TemplateCount + 1)
                    Assert-MockCalled Set-ItemProperty -Exactly $TemplateCount -ParameterFilter { ($Name -eq 'IsReadOnly') -and ($Value -eq $true) }
                    Assert-MockCalled Set-ItemProperty -Exactly $TemplateCount -ParameterFilter { ($Name -eq 'IsReadOnly') -and ($Value -eq $false) }
                    Assert-MockCalled Optimize-VHD -Exactly $TemplateCount
                    Assert-MockCalled New-Item -Exactly 3
                    Assert-MockCalled Mount-WindowsImage -Exactly 3
                    Assert-MockCalled Add-WindowsPackage -Exactly 3
                    Assert-MockCalled Dismount-WindowsImage -Exactly 3
                    Assert-MockCalled Remove-Item -Exactly 3
                }
            }

            Context 'Valid configuration is passed without VMTemplates' {
                Mock Test-Path -ParameterFilter { $Path -eq $ResourceWMFMSUFile } -MockWith { $true }
                Mock Test-Path -ParameterFilter { $Path -eq $ResourceRSATMSUFile } -MockWith { $true }

                It 'Does not throw an Exception' {
                    { Initialize-LabVMTemplate -Lab $Lab } | Should -Not -Throw
                }

                It 'Calls Mocked commands' {
                    Assert-MockCalled Copy-Item -Exactly ($TemplateCount + 1)
                    Assert-MockCalled Set-ItemProperty -Exactly $TemplateCount -ParameterFilter { ($Name -eq 'IsReadOnly') -and ($Value -eq $true) }
                    Assert-MockCalled Set-ItemProperty -Exactly $TemplateCount -ParameterFilter { ($Name -eq 'IsReadOnly') -and ($Value -eq $false) }
                    Assert-MockCalled Optimize-VHD -Exactly $TemplateCount
                    Assert-MockCalled New-Item -Exactly 3
                    Assert-MockCalled Mount-WindowsImage -Exactly 3
                    Assert-MockCalled Add-WindowsPackage -Exactly 3
                    Assert-MockCalled Dismount-WindowsImage -Exactly 3
                    Assert-MockCalled Remove-Item -Exactly 3
                }
            }
        }

        Describe 'Remove-LabVMTemplate' {
            # Mock functions
            function Get-VM {}

            $Lab = Get-Lab -ConfigPath $Global:TestConfigOKPath
            $TemplateCount = $Lab.labbuilderconfig.templates.template.count

            Mock Set-ItemProperty -ParameterFilter { ($Name -eq 'IsReadOnly') -and ($Value -eq $false) }
            Mock Remove-Item
            Mock Test-Path -MockWith { $true }
            Mock Get-VM

            Context 'Valid configuration is passed' {
                [Array]$Templates = Get-LabVMTemplate -Lab $Lab

                It 'Does not throw an Exception' {
                    { Remove-LabVMTemplate -Lab $Lab -VMTemplates $Templates } | Should -Not -Throw
                }

                It 'Calls Mocked commands' {
                    Assert-MockCalled Set-ItemProperty -Exactly $TemplateCount -ParameterFilter { ($Name -eq 'IsReadOnly') -and ($Value -eq $false) }
                    Assert-MockCalled Remove-Item -Exactly $TemplateCount
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
