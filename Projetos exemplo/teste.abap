CLASS lhc_Travel DEFINITION INHERITING FROM 
cl_abap_behavior_handler.
 PRIVATE SECTION.
 CONSTANTS:
 BEGIN OF travel_status,
 open TYPE c LENGTH 1 VALUE 'O', " Open
 accepted TYPE c LENGTH 1 VALUE 'A', " Accepted
 canceled TYPE c LENGTH 1 VALUE 'X', " Cancelled
 END OF travel_status.
 METHODS acceptTravel FOR MODIFY
 IMPORTING keys FOR ACTION Travel~acceptTravel RESULT result.
 METHODS rejectTravel FOR MODIFY
 IMPORTING keys FOR ACTION Travel~rejectTravel RESULT result.
 METHODS get_features FOR FEATURES
 IMPORTING keys REQUEST requested_features FOR Travel RESULT 
result.
 METHODS recalctotalprice FOR MODIFY
 IMPORTING keys FOR ACTION travel~recalcTotalPrice.
ENDCLASS.
CLASS lhc_Travel IMPLEMENTATION.
 METHOD acceptTravel.
 " Set the new overall status
 MODIFY ENTITIES OF zi_rap_travel_#### IN LOCAL MODE
 ENTITY Travel
 UPDATE
 FIELDS ( TravelStatus )
 WITH VALUE #( FOR key IN keys
 ( %tky = key-%tky
 TravelStatus = travel_status-accepted ) 
)
 FAILED failed
 REPORTED reported.
 " Fill the response table
 READ ENTITIES OF zi_rap_travel_#### IN LOCAL MODE
 ENTITY Travel
 ALL FIELDS WITH CORRESPONDING #( keys )
 RESULT DATA(travels).
 result = VALUE #( FOR travel IN travels
 ( %tky = travel-%tky
 %param = travel ) ).
 ENDMETHOD.
 METHOD rejectTravel.
 " Set the new overall status
 MODIFY ENTITIES OF zi_rap_travel_#### IN LOCAL MODE
 ENTITY Travel
 UPDATE
 FIELDS ( TravelStatus )
 WITH VALUE #( FOR key IN keys
 ( %tky = key-%tky
 TravelStatus = travel_status-canceled ) 
)
 FAILED failed
 REPORTED reported.
 " Fill the response table
 READ ENTITIES OF zi_rap_travel_#### IN LOCAL MODE
 ENTITY Travel
 ALL FIELDS WITH CORRESPONDING #( keys )
 RESULT DATA(travels).
 result = VALUE #( FOR travel IN travels
 ( %tky = travel-%tky
 %param = travel ) ).
 ENDMETHOD.
 METHOD get_features.
 " Read the travel status of the existing travels
 READ ENTITIES OF zi_rap_travel_#### IN LOCAL MODE
 ENTITY Travel
 FIELDS ( TravelStatus ) WITH CORRESPONDING #( keys )
 RESULT DATA(travels)
 FAILED failed.
 result =
 VALUE #(
 FOR travel IN travels
 LET is_accepted = COND #( WHEN travel-TravelStatus = 
travel_status-accepted
 THEN if_abap_behv=>fc-odisabled
 ELSE if_abap_behv=>fc-oenabled )
 is_rejected = COND #( WHEN travel-TravelStatus = 
travel_status-canceled
 THEN if_abap_behv=>fc-odisabled
 ELSE if_abap_behv=>fc-oenabled )
 IN
 ( %tky = travel-%tky
 %action-acceptTravel = is_accepted
 %action-rejectTravel = is_rejected
 ) ).
 ENDMETHOD.
 METHOD recalctotalprice.
 TYPES: BEGIN OF ty_amount_per_currencycode,
 amount TYPE /dmo/total_price,
 currency_code TYPE /dmo/currency_code,
 END OF ty_amount_per_currencycode.
 DATA: amount_per_currencycode TYPE STANDARD TABLE OF 
ty_amount_per_currencycode.
 " Read all relevant travel instances.
 READ ENTITIES OF zi_rap_travel_#### IN LOCAL MODE
 ENTITY Travel
 FIELDS ( BookingFee CurrencyCode )
 WITH CORRESPONDING #( keys )
 RESULT DATA(travels).
 DELETE travels WHERE CurrencyCode IS INITIAL.
 LOOP AT travels ASSIGNING FIELD-SYMBOL(<travel>).
 " Set the start for the calculation by adding the booking fee.
 amount_per_currencycode = VALUE #( ( amount = <travel>-
BookingFee
 currency_code = <travel>-
CurrencyCode ) ).
 " Read all associated bookings and add them to the total 
price.
 READ ENTITIES OF ZI_RAP_Travel_#### IN LOCAL MODE
 ENTITY Travel BY \_Booking
 FIELDS ( FlightPrice CurrencyCode )
 WITH VALUE #( ( %tky = <travel>-%tky ) )
 RESULT DATA(bookings).
 LOOP AT bookings INTO DATA(booking) WHERE CurrencyCode IS NOT 
INITIAL.
 COLLECT VALUE ty_amount_per_currencycode( amount = 
booking-FlightPrice
 currency_code = 
booking-CurrencyCode ) INTO amount_per_currencycode.
 ENDLOOP.
 CLEAR <travel>-TotalPrice.
 LOOP AT amount_per_currencycode INTO 
DATA(single_amount_per_currencycode).
 " If needed do a Currency Conversion
 IF single_amount_per_currencycode-currency_code = <travel>-
CurrencyCode.
 <travel>-TotalPrice += single_amount_per_currencycodeamount.
 ELSE.
 /dmo/cl_flight_amdp=>convert_currency(
 EXPORTING
 iv_amount = 
single_amount_per_currencycode-amount
 iv_currency_code_source = 
single_amount_per_currencycode-currency_code
 iv_currency_code_target = <travel>-CurrencyCode
 iv_exchange_rate_date = 
cl_abap_context_info=>get_system_date( )
 IMPORTING
 ev_amount = 
DATA(total_booking_price_per_curr)
 ).
 <travel>-TotalPrice += total_booking_price_per_curr.
 ENDIF.
 ENDLOOP.
 ENDLOOP.
 " write back the modified total_price of travels
 MODIFY ENTITIES OF ZI_RAP_Travel_#### IN LOCAL MODE
 ENTITY travel
 UPDATE FIELDS ( TotalPrice )
 WITH CORRESPONDING #( travels ).
 ENDMETHOD.
ENDCLASS