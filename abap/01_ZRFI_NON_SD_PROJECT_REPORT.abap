*&---------------------------------------------------------------------*
*& Report  ZRFI_NON_SD_PROJECT_REPORT
*&---------------------------------------------------------------------*
*& Description : Non-SD Project Billing & Collection Report
*&               (Profit Centre / Internal Order based)
*& Architecture: Local-class based, dynamic ALV with year-based columns
*&---------------------------------------------------------------------*
REPORT zrfi_non_sd_project_report.

*-- Global types, constants, data, class definitions
INCLUDE zifi_non_sd_project_report_top.

*-- Selection screen
INCLUDE zifi_non_sd_project_report_s01.

*-- Class implementations (controller + helpers)
INCLUDE zifi_non_sd_project_report_f01.

*&---------------------------------------------------------------------*
*&  Event blocks
*&---------------------------------------------------------------------*
INITIALIZATION.
  go_main = lcl_main=>get_instance( ).

AT SELECTION-SCREEN OUTPUT.
  go_main->modify_screen( ).

START-OF-SELECTION.
  go_main->get_data( ).
  go_main->process_data( ).
  go_main->display_report( ).
