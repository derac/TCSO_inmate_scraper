# This script scraped the TCSO inmate search using an input CSV which includes
# the person's first name, last name, and age. The output is a CSV which shows
# who turned up in the search results along with some data about the booking.
# Derek Olson Mar 2023

### SETTING UP THE INITIAL DATA

# Import the csv data, reference it from the root of where the script was
# run from to avoid issues with running the script while the current working
# directory is different.
$people_to_search_list = Import-Csv "$PSScriptRoot\input_data.csv"
$csv_output_file = "$PSScriptRoot\output_data.csv"
$inmate_search_url_template = "https://public.traviscountytx.gov/sip/api/v2/inmates?lastName={0}&firstName={1}"
$booking_lookup_url_template = "https://public.traviscountytx.gov/sip/api/v2/inmates/{0}"
# we will sleep after every http request to be nice to the host and hopefully not get banned
$sleep_time_ms = 500
# initialize the output as an empty array that we will add to in the loop as we scrape data
$output_csv_data = @()

### SEACHING FOR THE INFORMATION WE NEED AND BUILDING THE OUTPUT
# We will loop over each person in the csv, row by row
foreach ($person in $people_to_search_list) {
    $inmate_search_url = $inmate_search_url_template -f $person.last, $person.first
    Write-Host "Looking for $($person.first) $($person.last) aged $($person.age)"
    Write-Host "Scraping $inmate_search_url"
    $inmate_search_response = Invoke-WebRequest -Uri $inmate_search_url
    Start-Sleep -Milliseconds $sleep_time_ms
    $inmate_search_body = $inmate_search_response.Content
    $inmate_search_data = ConvertFrom-Json $inmate_search_body

    # filter the output by age, though this still might leave multiple results in rare cases
    $age_filtered_inmate_search_data = $inmate_search_data | where-object age -eq $person.age
    Write-Host "$($age_filtered_inmate_search_data.Count) people found"

    # loop over the results and include them all, in case more than one match is returned
    foreach ($result in $age_filtered_inmate_search_data) {
        $booking_number = $result.bookingNumber
        $booking_lookup_url = $booking_lookup_url_template -f $booking_number

        # make the call to get the booking
        Write-Host "Scraping $booking_lookup_url"
        $booking_lookup_response = Invoke-WebRequest -Uri $booking_lookup_url
        Start-Sleep -Milliseconds $sleep_time_ms
        $booking_lookup_body = $booking_lookup_response.Content
        $booking_lookup_data = ConvertFrom-Json $booking_lookup_body
        # building the output, the pscustomobject cast is needed
        # because it's what export-csv expects
        $output_csv_data += [PSCustomObject]@{
            first_name     = $person.first
            last_name      = $person.last
            age            = $person.age
            date_of_birth  = $person.date_of_birth
            name           = $booking_lookup_data.fullName
            booking_date   = $booking_lookup_data.bookingDate
            booking_number = $booking_lookup_data.bookingNumber
            data_url       = $booking_lookup_url
        }
    }
}

$output_csv_data | Export-Csv -Path $csv_output_file -NoTypeInformation -Force