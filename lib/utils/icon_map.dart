import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

/// Centralized icon mapping — single source of truth for all app icons.
/// Uses Iconsax Plus (Linear for outlines, Bold for filled variants).
class AppIcons {
  AppIcons._();

  // ============================================
  // Navigation (outline / bold pairs)
  // ============================================
  static const IconData homeOutline = IconsaxPlusLinear.home_1;
  static const IconData homeBold = IconsaxPlusBold.home_1;
  static const IconData briefcaseOutline = IconsaxPlusLinear.briefcase;
  static const IconData briefcaseBold = IconsaxPlusBold.briefcase;
  static const IconData receiptOutline = IconsaxPlusLinear.receipt;
  static const IconData receiptBold = IconsaxPlusBold.receipt;
  static const IconData settingOutline = IconsaxPlusLinear.setting_2;
  static const IconData settingBold = IconsaxPlusBold.setting_2;

  // ============================================
  // Actions
  // ============================================
  static const IconData add = IconsaxPlusLinear.add;
  static const IconData addCircle = IconsaxPlusLinear.add_circle;
  static const IconData edit = IconsaxPlusLinear.edit_2;
  static const IconData editNote = IconsaxPlusLinear.note_2;
  static const IconData trash = IconsaxPlusLinear.trash;
  static const IconData search = IconsaxPlusLinear.search_normal;
  static const IconData close = IconsaxPlusLinear.close_circle;
  static const IconData send = IconsaxPlusLinear.send_2;
  static const IconData share = IconsaxPlusLinear.share;
  static const IconData copy = IconsaxPlusLinear.copy;
  static const IconData save = IconsaxPlusLinear.save_2;
  static const IconData refresh = IconsaxPlusLinear.refresh;
  static const IconData play = IconsaxPlusLinear.play;
  static const IconData logout = IconsaxPlusLinear.logout;

  // ============================================
  // Status
  // ============================================
  static const IconData tickCircle = IconsaxPlusLinear.tick_circle;
  static const IconData tickCircleBold = IconsaxPlusBold.tick_circle;
  static const IconData warning = IconsaxPlusLinear.warning_2;
  static const IconData infoCircle = IconsaxPlusLinear.info_circle;
  static const IconData danger = IconsaxPlusLinear.danger;

  // ============================================
  // Objects
  // ============================================
  static const IconData calendar = IconsaxPlusLinear.calendar;
  static const IconData clock = IconsaxPlusLinear.clock;
  static const IconData document = IconsaxPlusLinear.document_text;
  static const IconData documentBold = IconsaxPlusBold.document_text;
  static const IconData folder = IconsaxPlusLinear.folder;
  static const IconData wallet = IconsaxPlusLinear.wallet;
  static const IconData walletBold = IconsaxPlusBold.wallet;
  static const IconData bank = IconsaxPlusLinear.bank;
  static const IconData receipt = IconsaxPlusLinear.receipt;
  static const IconData receiptItem = IconsaxPlusLinear.receipt_item;
  static const IconData receiptEdit = IconsaxPlusLinear.receipt_edit;
  static const IconData note = IconsaxPlusLinear.note;
  static const IconData noteText = IconsaxPlusLinear.note_text;
  static const IconData clipboard = IconsaxPlusLinear.clipboard_text;
  static const IconData clipboardTick = IconsaxPlusLinear.clipboard_tick;

  // ============================================
  // People
  // ============================================
  static const IconData user = IconsaxPlusLinear.user;
  static const IconData userBold = IconsaxPlusBold.user;
  static const IconData people = IconsaxPlusLinear.people;
  static const IconData peopleBold = IconsaxPlusBold.people;
  static const IconData profile = IconsaxPlusLinear.profile;
  static const IconData profileCircle = IconsaxPlusLinear.profile_circle;
  static const IconData profile2User = IconsaxPlusLinear.profile_2user;

  // ============================================
  // Places & Objects
  // ============================================
  static const IconData location = IconsaxPlusLinear.location;
  static const IconData locationBold = IconsaxPlusBold.location;
  static const IconData locationSlash = IconsaxPlusLinear.location_slash;
  static const IconData building = IconsaxPlusLinear.building;
  static const IconData buildingBold = IconsaxPlusBold.building;

  // ============================================
  // Tools
  // ============================================
  static const IconData toggleOn = IconsaxPlusLinear.toggle_on;
  static const IconData sound = IconsaxPlusLinear.sound;
  static const IconData volumeHigh = IconsaxPlusLinear.volume_high;
  static const IconData batteryCharging = IconsaxPlusLinear.battery_charging;
  static const IconData batteryFull = IconsaxPlusLinear.battery_full;
  static const IconData book = IconsaxPlusLinear.book;
  static const IconData calculator = IconsaxPlusLinear.calculator;
  static const IconData flash = IconsaxPlusLinear.flash;
  static const IconData flashBold = IconsaxPlusBold.flash;
  static const IconData lamp = IconsaxPlusLinear.lamp;
  static const IconData ruler = IconsaxPlusLinear.ruler;
  static const IconData scanner = IconsaxPlusLinear.scanner;
  static const IconData camera = IconsaxPlusLinear.camera;
  static const IconData video = IconsaxPlusLinear.video;
  static const IconData record = IconsaxPlusLinear.record;
  static const IconData stop = IconsaxPlusLinear.stop;
  static const IconData flashSlash = IconsaxPlusLinear.flash_slash;
  static const IconData rotateRight = IconsaxPlusLinear.rotate_right;

  // ============================================
  // UI / Navigation
  // ============================================
  static const IconData arrowRight = IconsaxPlusLinear.arrow_right_3;
  static const IconData arrowLeft = IconsaxPlusLinear.arrow_left_2;
  static const IconData arrowDown = IconsaxPlusLinear.arrow_down_1;
  static const IconData arrowUp = IconsaxPlusLinear.arrow_up_1;
  static const IconData more = IconsaxPlusLinear.more;
  static const IconData menu = IconsaxPlusLinear.menu;
  static const IconData category = IconsaxPlusLinear.category;
  static const IconData categoryBold = IconsaxPlusBold.category;
  static const IconData element = IconsaxPlusLinear.element_3;
  static const IconData grid = IconsaxPlusLinear.grid_1;
  static const IconData eye = IconsaxPlusLinear.eye;
  static const IconData eyeSlash = IconsaxPlusLinear.eye_slash;

  // ============================================
  // Design / Branding
  // ============================================
  static const IconData colorSwatch = IconsaxPlusLinear.color_swatch;
  static const IconData paintBucket = IconsaxPlusLinear.paintbucket;
  static const IconData designtools = IconsaxPlusLinear.designtools;
  static const IconData brush = IconsaxPlusLinear.brush;
  static const IconData magicPen = IconsaxPlusLinear.magicpen;

  // ============================================
  // Communication
  // ============================================
  static const IconData sms = IconsaxPlusLinear.sms;
  static const IconData directNormal = IconsaxPlusLinear.direct_normal;
  static const IconData messageQuestion = IconsaxPlusLinear.message_question;
  static const IconData message = IconsaxPlusLinear.message;

  // ============================================
  // Dispatch
  // ============================================
  static const IconData taskOutline = IconsaxPlusLinear.task_square;
  static const IconData taskBold = IconsaxPlusBold.task_square;
  static const IconData routing = IconsaxPlusLinear.routing;
  static const IconData call = IconsaxPlusLinear.call;
  static const IconData map = IconsaxPlusLinear.map;
  static const IconData timer = IconsaxPlusLinear.timer;
  static const IconData crown = IconsaxPlusLinear.crown;
  static const IconData userAdd = IconsaxPlusLinear.user_add;

  // ============================================
  // Misc
  // ============================================
  static const IconData searchOff = IconsaxPlusLinear.search_zoom_out;
  static const IconData briefcaseTimer = IconsaxPlusLinear.brifecase_timer;
  static const IconData tag = IconsaxPlusLinear.tag;
  static const IconData stickynote = IconsaxPlusLinear.stickynote;
  static const IconData layer = IconsaxPlusLinear.layer;
  static const IconData slider = IconsaxPlusLinear.slider_horizontal;
  static const IconData task = IconsaxPlusLinear.task_square;
  static const IconData gallery = IconsaxPlusLinear.gallery;
  static const IconData key = IconsaxPlusLinear.key;
  static const IconData lock = IconsaxPlusLinear.lock;
  static const IconData global = IconsaxPlusLinear.global;
  static const IconData printer = IconsaxPlusLinear.printer;
  static const IconData microphone = IconsaxPlusLinear.microphone;
  static const IconData notification = IconsaxPlusLinear.notification;
  static const IconData shield = IconsaxPlusLinear.shield_tick;
  static const IconData image = IconsaxPlusLinear.image;
  static const IconData award = IconsaxPlusLinear.award;
}
