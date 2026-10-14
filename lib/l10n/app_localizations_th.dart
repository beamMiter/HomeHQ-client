// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Thai (`th`).
class AppLocalizationsTh extends AppLocalizations {
  AppLocalizationsTh([String locale = 'th']) : super(locale);

  @override
  String get commonTryAgain => 'ลองอีกครั้ง';

  @override
  String get commonCancel => 'ยกเลิก';

  @override
  String get commonSave => 'บันทึก';

  @override
  String get commonDelete => 'ลบ';

  @override
  String get commonEdit => 'แก้ไข';

  @override
  String get commonClear => 'ล้าง';

  @override
  String get commonApply => 'ใช้งาน';

  @override
  String get commonClose => 'ปิด';

  @override
  String get commonBack => 'กลับ';

  @override
  String get commonSearch => 'ค้นหา…';

  @override
  String get commonAll => 'ทั้งหมด';

  @override
  String get commonYes => 'ใช่';

  @override
  String get commonNo => 'ไม่';

  @override
  String get commonLoadFailed => 'โหลดข้อมูลไม่สำเร็จ';

  @override
  String get languageTitle => 'ภาษา';

  @override
  String get languageSystem => 'ตามภาษาของเครื่อง';

  @override
  String get languageThai => 'ไทย';

  @override
  String get languageEnglish => 'English';

  @override
  String get refreshTooltip => 'รีเฟรช';

  @override
  String get refreshDone => 'อัปเดตแล้ว';

  @override
  String get refreshFailed => 'รีเฟรชไม่สำเร็จ ลองใหม่อีกครั้ง';

  @override
  String get homeNotifications => 'การแจ้งเตือน';

  @override
  String get homeNotificationsSoon => 'การแจ้งเตือนกำลังจะมาเร็วๆ นี้';

  @override
  String get homeToolsTitle => 'เครื่องมือ';

  @override
  String get homeToolsSubtitle => 'จัดการบ้านได้รวดเร็ว';

  @override
  String get homeWeatherFailed => 'โหลดสภาพอากาศไม่สำเร็จ';

  @override
  String get homeWind => 'ลม';

  @override
  String get homeUpdated => 'อัปเดตเมื่อ';

  @override
  String get homeSearchHint => 'ค้นหาช่างไฟ ช่างประปา…';

  @override
  String get weatherClear => 'ท้องฟ้าแจ่มใส';

  @override
  String get weatherPartlyCloudy => 'มีเมฆบางส่วน';

  @override
  String get weatherFog => 'หมอก';

  @override
  String get weatherDrizzle => 'ฝนปรอย';

  @override
  String get weatherRain => 'ฝนตก';

  @override
  String get weatherSnow => 'หิมะ';

  @override
  String get weatherThunderstorm => 'พายุฝนฟ้าคะนอง';

  @override
  String get weatherUnknown => 'ไม่ทราบ';

  @override
  String get toolContractorsCaption => 'รายชื่อช่างตามตำแหน่ง';

  @override
  String get toolNotesCaption => 'บันทึกสำคัญกันลืม';

  @override
  String get toolCamerasCaption => 'ดูกล้องวงจรปิดที่บ้าน';

  @override
  String get toolPurchasesCaption => 'ติดตามของที่ซื้อเข้าบ้าน';

  @override
  String get toolBillsCaption => 'บิลค่าใช้จ่ายประจำ';

  @override
  String get toolMedicineCaption => 'เช็คสต็อกยาประจำบ้าน';

  @override
  String get commonConfirm => 'ยืนยัน';

  @override
  String get commonInvalidNumber => 'ตัวเลขไม่ถูกต้อง';

  @override
  String get medAlertTitle => 'ตั้งเตือน';

  @override
  String get medAlertEnable => 'เปิดการเตือน';

  @override
  String get medAlertMinQty => 'แจ้งเตือนเมื่อคงเหลือ ≤ (ชิ้น)';

  @override
  String get medAlertExpiryDays => 'แจ้งเตือนเมื่อเหลือวันหมดอายุ ≤ (วัน)';

  @override
  String get medAlertUpdated => 'อัปเดตการเตือนแล้ว';

  @override
  String get medAlertNone => 'ไม่ตั้งเตือน';

  @override
  String medAlertOn(String min, String days) {
    return 'เปิด · ขั้นต่ำ $min · หมดอายุ $days วัน';
  }

  @override
  String get medAlertOff => 'ปิด';

  @override
  String get medTxnInTitle => 'รับเข้า';

  @override
  String get medTxnOutTitle => 'เบิกยา';

  @override
  String get medTxnLot => 'เลขล็อต (ถ้ามี)';

  @override
  String get medTxnExpiry => 'วันหมดอายุ (YYYY-MM-DD)';

  @override
  String get medTxnQty => 'จำนวน (ชิ้น)';

  @override
  String get medTxnQtyInvalid => 'ใส่จำนวนให้ถูกต้อง';

  @override
  String get medTxnNote => 'บันทึก (ถ้ามี)';

  @override
  String get medTxnInDone => 'รับเข้าสต็อกแล้ว';

  @override
  String get medTxnOutDone => 'เบิกยาแล้ว';

  @override
  String medBatchLot(String lot) {
    return 'Lot $lot';
  }

  @override
  String get medBatchNoLot => 'ไม่มีเลขล็อต';

  @override
  String medBatchExpires(String date) {
    return 'หมดอายุ: $date';
  }

  @override
  String medInStock(String qty) {
    return 'คงเหลือ $qty';
  }

  @override
  String get billsNew => 'บิลใหม่';

  @override
  String get billsSummaryTooltip => 'สรุป';

  @override
  String get billsSearchHint => 'ค้นหาบิล (หัวข้อ/หมายเหตุ/ประเภท)…';

  @override
  String get billsEmptyTitle => 'ยังไม่มีบิล';

  @override
  String get billsEmptyHint => 'เพิ่มบิลแรกเพื่อเริ่มติดตามค่าใช้จ่าย';

  @override
  String get billsClearFilters => 'ล้างตัวกรอง';

  @override
  String get billStatusPaid => 'ชำระแล้ว';

  @override
  String get billStatusUnpaid => 'ยังไม่ชำระ';

  @override
  String billsPaidOn(String date) {
    return 'ชำระเมื่อ $date';
  }

  @override
  String get billsDueToday => 'ครบกำหนดวันนี้';

  @override
  String get billsDueTomorrow => 'ครบกำหนดพรุ่งนี้';

  @override
  String billsDueInDays(int days) {
    return 'ครบกำหนดใน $days วัน';
  }

  @override
  String billsLateDays(int days) {
    return 'เลยกำหนด $days วัน';
  }

  @override
  String billsDueOn(String date) {
    return 'ครบกำหนด $date';
  }

  @override
  String get billTypeElectric => 'ค่าไฟ';

  @override
  String get billTypeWater => 'ค่าน้ำ';

  @override
  String get billTypeInternet => 'อินเทอร์เน็ต';

  @override
  String get billTypePhone => 'โทรศัพท์';

  @override
  String get billTypeOther => 'อื่นๆ';

  @override
  String get billDetailTitle => 'รายละเอียดบิล';

  @override
  String get billDetailAmount => 'จำนวนเงิน';

  @override
  String get billDetailStatus => 'สถานะ';

  @override
  String get billDetailDueDate => 'วันครบกำหนด';

  @override
  String get billDetailCreatedAt => 'สร้างเมื่อ';

  @override
  String get billDetailUpdatedAt => 'แก้ไขล่าสุด';

  @override
  String get billDetailCreatedBy => 'สร้างโดย';

  @override
  String get billDetailNote => 'หมายเหตุ';

  @override
  String get billMarkPaid => 'ทำเครื่องหมายว่าชำระแล้ว';

  @override
  String get billProcessing => 'กำลังดำเนินการ…';

  @override
  String get billMarkedPaid => 'ทำเครื่องหมายว่าชำระแล้ว';

  @override
  String get billFormPickDue => 'เลือกวันที่ครบกำหนด';

  @override
  String get billFormType => 'ประเภท';

  @override
  String get billFormTitle => 'ชื่อบิล';

  @override
  String get billFormTitleRequired => 'กรอกชื่อบิล';

  @override
  String get billFormAmount => 'จำนวนเงิน (บาท)';

  @override
  String get billFormAmountInvalid => 'จำนวนเงินไม่ถูกต้อง';

  @override
  String get billFormAmountPositive => 'จำนวนเงินต้องมากกว่า 0';

  @override
  String get billFormNote => 'หมายเหตุ (ถ้ามี)';

  @override
  String get billFormPickDueFirst => 'กรุณาเลือกวันที่ครบกำหนด';

  @override
  String get billFormDuePast => 'วันครบกำหนดต้องไม่เป็นอดีต';

  @override
  String get billFormCreated => 'สร้างบิลสำเร็จ';

  @override
  String get billsSummaryTitle => 'สรุปบิล';

  @override
  String get billsSummaryFailed => 'โหลดสรุปไม่สำเร็จ';

  @override
  String get billsSummaryEmpty => 'ยังไม่มีข้อมูลสรุปบิล';

  @override
  String get medNew => 'เพิ่มยาใหม่';

  @override
  String get medSearchHint => 'ค้นหาชื่อยา…';

  @override
  String get medEmptyTitle => 'ยังไม่มียาในระบบ';

  @override
  String get medEmptyHint => 'กดปุ่ม “เพิ่มยาใหม่” เพื่อสร้างรายการแรก';

  @override
  String get medLoadFailed => 'โหลดรายการยาไม่สำเร็จ';

  @override
  String get medStatusExpired => 'หมดอายุ';

  @override
  String get medStatusExpiringSoon => 'ใกล้หมดอายุ';

  @override
  String get medStatusLow => 'ใกล้หมด';

  @override
  String medUnit(String unit) {
    return 'หน่วย: $unit';
  }

  @override
  String medNextExpiry(String date) {
    return 'หมดอายุถัดไป $date';
  }

  @override
  String get medDetailTitle => 'รายละเอียดยา';

  @override
  String medDetailExpiringSoon(String date) {
    return 'ใกล้หมดอายุ: $date';
  }

  @override
  String get medDetailLots => 'ล็อตยา';

  @override
  String get medDetailNoLots => 'ยังไม่มีล็อตยา';

  @override
  String get medDetailNoLotsHint => 'กด “รับเข้า” เพื่อเพิ่มล็อตแรก';

  @override
  String get medDetailAlerts => 'การเตือน';

  @override
  String get medFormAdded => 'เพิ่มยาเรียบร้อย';

  @override
  String get medFormName => 'ชื่อยา';

  @override
  String get medFormNameHint => 'เช่น Paracetamol 500mg';

  @override
  String get medFormNameRequired => 'กรุณากรอกชื่อยา';

  @override
  String get medFormForm => 'รูปแบบยา (เช่น tablet, syrup)';

  @override
  String get medFormUnit => 'หน่วย (เช่น tab, ml)';

  @override
  String get medFormCategory => 'หมวดหมู่ (เช่น painkiller)';

  @override
  String get medFormNoLocation => '— ไม่ระบุที่เก็บ —';

  @override
  String get medFormLocation => 'ที่เก็บยา';

  @override
  String get medFormLocationsFailed => 'โหลดรายการที่เก็บยาไม่สำเร็จ';

  @override
  String get commonStatus => 'สถานะ';

  @override
  String get commonNote => 'หมายเหตุ';

  @override
  String get commonFilters => 'ตัวกรอง';

  @override
  String get commonClearFilters => 'ล้างตัวกรอง';

  @override
  String get commonClearAll => 'ล้างทั้งหมด';

  @override
  String get authSignIn => 'เข้าสู่ระบบ';

  @override
  String get purchNew => 'รายการซื้อใหม่';

  @override
  String get purchAddItem => 'เพิ่มรายการ';

  @override
  String get purchSearchHint => 'ค้นหา (หัวข้อ/ร้าน/หมวดหมู่/หมายเหตุ/สถานะ)…';

  @override
  String get purchStatusPlanned => 'วางแผน';

  @override
  String get purchStatusOrdered => 'สั่งซื้อแล้ว';

  @override
  String get purchStatusBought => 'ซื้อแล้ว';

  @override
  String get purchStatusDelivered => 'ส่งมอบแล้ว';

  @override
  String get purchStatusCanceled => 'ยกเลิก';

  @override
  String get purchNoResults => 'ไม่พบรายการตามเงื่อนไข';

  @override
  String get purchEmpty => 'ยังไม่มีรายการสั่งซื้อ';

  @override
  String get purchSignInPrompt => 'กรุณาเข้าสู่ระบบก่อนใช้งาน';

  @override
  String get purchLoadFailed => 'ไม่สามารถโหลดข้อมูลได้';

  @override
  String get purchDetailTitle => 'รายละเอียดรายการซื้อ';

  @override
  String purchDetailLoadFailed(String error) {
    return 'โหลดไม่สำเร็จ: $error';
  }

  @override
  String get purchAdvanceSoon => 'ยังไม่ได้ต่อ API: เปลี่ยนสถานะ';

  @override
  String get purchUploading => 'กำลังอัปโหลดไฟล์…';

  @override
  String get purchUploadDone => 'อัปโหลดไฟล์สำเร็จ';

  @override
  String purchUploadFailed(String error) {
    return 'อัปโหลดไฟล์ล้มเหลว: $error';
  }

  @override
  String get purchItemsTitle => 'รายการสินค้า';

  @override
  String purchItemsCount(int count) {
    return '$count รายการ';
  }

  @override
  String get purchNoItems => '— ไม่มีรายการ —';

  @override
  String get purchTotalByItems => 'รวมตามรายการ';

  @override
  String get purchEstimated => 'ประมาณการ';

  @override
  String get purchPaid => 'จ่ายจริง';

  @override
  String get purchAttachments => 'ไฟล์แนบ';

  @override
  String purchEstimatedAmount(String amount) {
    return 'ประมาณ $amount';
  }

  @override
  String purchPaidAmount(String amount) {
    return 'จ่ายจริง $amount';
  }

  @override
  String purchItemQty(String qty) {
    return 'จำนวน: $qty';
  }

  @override
  String purchItemPrice(String price) {
    return '• $price / หน่วย';
  }

  @override
  String get purchNextStatus => 'สถานะถัดไป';

  @override
  String get purchAttach => 'แนบไฟล์/รูป';

  @override
  String get purchNoAttachments => '— ไม่มีไฟล์แนบ —';

  @override
  String get purchOpen => 'เปิดดู';

  @override
  String get purchCantOpenLink => 'ไม่สามารถเปิดลิงก์ได้';

  @override
  String get purchDeleteAttachment => 'ลบไฟล์แนบ';

  @override
  String get purchDeleteAttachmentAsk => 'ลบไฟล์แนบ?';

  @override
  String purchDeleteAttachmentBody(String name) {
    return 'ต้องการลบไฟล์ “$name” ใช่หรือไม่?';
  }

  @override
  String get purchDeleting => 'กำลังลบไฟล์แนบ…';

  @override
  String get purchDeleted => 'ลบไฟล์แนบสำเร็จ';

  @override
  String purchDeleteFailed(String error) {
    return 'ลบไฟล์แนบล้มเหลว: $error';
  }

  @override
  String get purchFormCreate => 'สร้างรายการซื้อ';

  @override
  String get purchFormEdit => 'แก้ไขรายการซื้อ';

  @override
  String get purchFormTitleRequired => 'กรอกหัวข้อรายการ';

  @override
  String get purchFormTitleMin => 'อย่างน้อย 3 ตัวอักษร';

  @override
  String get purchFormPositive => 'ต้องมากกว่า 0';

  @override
  String get purchFormCreated => 'สร้างรายการสำเร็จ';

  @override
  String get purchFormError => 'เกิดข้อผิดพลาด';

  @override
  String get purchFormSignIn => 'กรุณาเข้าสู่ระบบ';

  @override
  String get purchFormDetails => 'รายละเอียดรายการ';

  @override
  String get purchFormTitleLabel => 'หัวข้อ *';

  @override
  String get purchFormTitleHint => 'เช่น “ซื้ออุปกรณ์ทำความสะอาด”';

  @override
  String get purchFormNoteHint => 'รายละเอียดเพิ่มเติม (ไม่บังคับ)';

  @override
  String get purchFormBudget => 'งบประมาณคร่าว ๆ';

  @override
  String get purchFormEstimated => 'จำนวนเงินโดยประมาณ';

  @override
  String get purchFormEstimatedHint => 'เช่น 1,500 หรือ 1500';

  @override
  String get purchFormCurrency => 'สกุลเงิน';

  @override
  String get purchFormOptional => 'ใส่ได้หรือเว้นว่างถ้ายังไม่แน่ใจ';

  @override
  String get purchFormSaving => 'กำลังบันทึก…';

  @override
  String get commonError => 'เกิดข้อผิดพลาด';

  @override
  String get notesNew => 'โน้ตใหม่';

  @override
  String get notesEditTitle => 'แก้ไขโน้ต';

  @override
  String get notesStatusActive => 'กำลังทำ';

  @override
  String get notesStatusDone => 'เสร็จแล้ว';

  @override
  String get notesStatusOverdue => 'เกินกำหนด';

  @override
  String get notesPinned => 'ปักหมุด';

  @override
  String get notesUnpinned => 'ไม่ได้ปักหมุด';

  @override
  String get notesCategory => 'หมวดหมู่';

  @override
  String get notesCatBills => 'บิล';

  @override
  String get notesCatChores => 'งานบ้าน';

  @override
  String get notesCatAppointment => 'นัดหมาย';

  @override
  String get notesCatGeneral => 'ทั่วไป';

  @override
  String get notesTag => 'แท็ก';

  @override
  String get notesNoMatch => 'ไม่พบโน้ตที่ตรงกับเงื่อนไข';

  @override
  String get notesMarkedDone => 'ทำเสร็จแล้ว';

  @override
  String get notesMarkedUndone => 'ยกเลิกเสร็จสิ้นแล้ว';

  @override
  String get notesErrDone => 'อัปเดตสถานะไม่สำเร็จ';

  @override
  String get notesErrPin => 'เปลี่ยนการปักหมุดไม่สำเร็จ';

  @override
  String get notesErrDelete => 'ลบโน้ตไม่สำเร็จ';

  @override
  String get notesErrSave => 'บันทึกโน้ตไม่สำเร็จ';

  @override
  String notesErr401(String what) {
    return '$what: 401 (โปรดเข้าสู่ระบบใหม่)';
  }

  @override
  String notesErr404(String what) {
    return '$what: 404 (ไม่พบข้อมูล)';
  }

  @override
  String get notesDeleteTitle => 'ลบโน้ต';

  @override
  String notesDeleteBody(String title) {
    return 'ลบ “$title” ?';
  }

  @override
  String get notesDeleted => 'ลบแล้ว';

  @override
  String get notesAdded => 'เพิ่มโน้ตแล้ว';

  @override
  String get notesEdited => 'แก้ไขโน้ตแล้ว';

  @override
  String get notesSearchHint => 'ค้นหาโน้ต (หัวข้อ/เนื้อหา/แท็ก)';

  @override
  String get notesCopy => 'คัดลอก';

  @override
  String get notesCopied => 'คัดลอกแล้ว';

  @override
  String get notesMarkDone => 'เสร็จสิ้น';

  @override
  String get notesMarkUndone => 'ยกเลิกเสร็จสิ้น';

  @override
  String get notesPin => 'ปักหมุด';

  @override
  String get notesUnpin => 'เลิกปักหมุด';

  @override
  String get notesFieldTitle => 'หัวข้อ';

  @override
  String get notesFieldContent => 'เนื้อหา (วางลิงก์รูปจาก Uploads ได้)';

  @override
  String get notesTitleRequired => 'กรุณากรอกหัวข้อ';

  @override
  String get notesCreate => 'สร้าง';

  @override
  String get notesErrUnauthorized =>
      'ไม่ได้รับอนุญาต (401) — กรุณาเข้าสู่ระบบอีกครั้ง';

  @override
  String get notesErrNotFound => 'ไม่พบข้อมูลโน้ต (404)';

  @override
  String notesErrLoad(String detail) {
    return 'โหลดโน้ตล้มเหลว: $detail';
  }

  @override
  String distMeters(String m) {
    return '$m ม.';
  }

  @override
  String distKm(String km) {
    return '$km กม.';
  }

  @override
  String get contStarred => 'ติดดาวแล้ว';

  @override
  String get contUnstarred => 'เอาดาวออกแล้ว';

  @override
  String get contStarFailed => 'บันทึกดาวไม่สำเร็จ ลองใหม่อีกครั้ง';

  @override
  String get contBackToMe => 'กลับมาที่ฉัน';

  @override
  String get contFavorites => 'ช่างประจำ';

  @override
  String get contStopFollow => 'หยุดตามตำแหน่ง';

  @override
  String get contMyLocation => 'ตำแหน่งของฉัน';

  @override
  String get contFitAll => 'ดูทั้งหมด';

  @override
  String get contMeasureOff => 'ปิดการวัดระยะ';

  @override
  String get contMeasure => 'วัดระยะ';

  @override
  String get contPinPlaced =>
      'ปักหมุดตำแหน่งแล้ว แตะ “ตำแหน่งของฉัน” เพื่อกลับไปใช้ GPS';

  @override
  String get contPinnedSpot => 'ตำแหน่งที่ปักไว้';

  @override
  String get contYouAreHere => 'คุณอยู่ที่นี่';

  @override
  String get contGoogleLimited =>
      'ใช้โควตา Google ของวันนี้ครบแล้ว แสดงเฉพาะช่างที่บันทึกไว้';

  @override
  String get contGoogleBusy => 'ค้นหาถี่เกินไป รอสักครู่แล้วลองใหม่';

  @override
  String get contGoogleDown =>
      'ดึงข้อมูลจาก Google ไม่ได้ในตอนนี้ แสดงเฉพาะช่างที่บันทึกไว้';

  @override
  String get contGoogleIncluded => 'รวมร้านจาก Google';

  @override
  String get contGoogleIncludedListOnly =>
      'รวมร้านจาก Google (แสดงในรายการเท่านั้น)';

  @override
  String contGoogleLeft(int left) {
    return 'โควตา Google วันนี้เหลือ $left ครั้ง';
  }

  @override
  String get contGoogleHowTo =>
      'แตะประเภทช่างหรือพิมพ์ค้นหา เพื่อหาร้านจาก Google';

  @override
  String get contNeedLocation => 'ต้องใช้ตำแหน่งของคุณเพื่อหานายช่างใกล้เคียง';

  @override
  String get contLocateAgain => 'หาตำแหน่งอีกครั้ง';

  @override
  String get contLoadFailed => 'โหลดรายชื่อนายช่างไม่สำเร็จ';

  @override
  String get contNoFavorites => 'ยังไม่มีช่างประจำ';

  @override
  String get contNoFavoritesHint =>
      'แตะดาวที่การ์ดของช่างที่ไว้ใจ เพื่อเก็บไว้ที่นี่';

  @override
  String get contNoneInRadius => 'ไม่พบนายช่างในรัศมีที่เลือก';

  @override
  String contWidenRadius(int km) {
    return 'ขยายรัศมีเป็น $km กม.';
  }

  @override
  String contSeeMore(int hidden) {
    return 'ดูเพิ่ม (เหลืออีก $hidden)';
  }

  @override
  String get contNearYou => 'นายช่างใกล้คุณ';

  @override
  String contFound(int count) {
    return 'พบ $count ราย';
  }

  @override
  String get contSearchHere => 'ค้นหาในพื้นที่นี้';

  @override
  String get contSearchHint => 'ค้นหาช่าง เช่น ช่างไฟ, ชื่อร้าน';

  @override
  String get contOpenNow => 'เปิดอยู่';

  @override
  String get contClosedNow => 'ปิดอยู่';

  @override
  String get contStarRemove => 'เอาดาวออก';

  @override
  String get contStarAdd => 'ติดดาวช่างประจำ';

  @override
  String get contCall => 'โทร';

  @override
  String get contDirections => 'นำทาง';

  @override
  String get contWebsite => 'เว็บไซต์';

  @override
  String get contOpenInGoogle => 'เปิดใน Google Maps';

  @override
  String get contMeasureHint0 => 'แตะบนแผนที่หรือหมุดนายช่างเพื่อเริ่มวัดระยะ';

  @override
  String get contMeasureHint1 => 'แตะจุดถัดไปเพื่อวัดระยะ';

  @override
  String get contMeasureHintMore =>
      'แตะเพิ่มเพื่อต่อเส้นทาง (ระยะเป็นเส้นตรงระหว่างจุด)';

  @override
  String contPoints(int points) {
    return '($points จุด)';
  }

  @override
  String get contStartFromMe => 'เริ่มจากตำแหน่งฉัน';

  @override
  String get contUndo => 'ย้อนกลับ';

  @override
  String get contDone => 'เสร็จ';

  @override
  String get contRadiusTitle => 'รัศมีค้นหา';

  @override
  String contRadiusFromYou(int km) {
    return '$km กม. จากตำแหน่งของคุณ';
  }

  @override
  String get contTypeElectrician => 'ช่างไฟ';

  @override
  String get contTypePlumber => 'ช่างประปา';

  @override
  String get contTypeCarpenter => 'ช่างไม้';

  @override
  String get contTypeHvac => 'ช่างแอร์';

  @override
  String get contTypeOther => 'ช่างทั่วไป';

  @override
  String get locServiceOff =>
      'ยังไม่ได้เปิดบริการตำแหน่ง (Location Services) ของเครื่อง';

  @override
  String get locOpenSettings => 'เปิดการตั้งค่า';

  @override
  String get locDenied => 'ยังไม่ได้อนุญาตให้แอปเข้าถึงตำแหน่ง';

  @override
  String get locAllow => 'อนุญาต';

  @override
  String get locBlocked =>
      'การเข้าถึงตำแหน่งถูกบล็อก เปิดได้ในการตั้งค่าของแอป';

  @override
  String get locUnavailable =>
      'ยังหาตำแหน่งปัจจุบันไม่ได้ (ถ้าใช้ Simulator ให้ตั้งตำแหน่งก่อน)';

  @override
  String get locErrServiceOff => 'บริการตำแหน่งปิดอยู่';

  @override
  String get locErrDenied => 'ไม่ได้รับอนุญาตให้ใช้ตำแหน่ง';

  @override
  String get locErrBlocked => 'การเข้าถึงตำแหน่งถูกบล็อก เปิดได้ในการตั้งค่า';

  @override
  String get locErrUnknown => 'หาตำแหน่งของคุณไม่ได้';

  @override
  String get authInvalidCredentials => 'อีเมลหรือรหัสผ่านไม่ถูกต้อง';

  @override
  String get authLoginSubtitle => 'เข้าสู่ระบบเพื่อจัดการงานและบริการของบ้าน';

  @override
  String get authEmail => 'อีเมล';

  @override
  String get authEmailRequired => 'กรุณากรอกอีเมล';

  @override
  String get authEmailInvalid => 'รูปแบบอีเมลไม่ถูกต้อง';

  @override
  String get authPassword => 'รหัสผ่าน';

  @override
  String get authShowPassword => 'แสดงรหัสผ่าน';

  @override
  String get authHidePassword => 'ซ่อนรหัสผ่าน';

  @override
  String get authPasswordRequired => 'กรุณากรอกรหัสผ่าน';

  @override
  String get authForgot => 'ลืมรหัสผ่าน?';

  @override
  String get authCreateAccountLink => 'สร้างบัญชีใหม่';

  @override
  String get authPrivacyNote => 'เราเก็บข้อมูลของคุณอย่างปลอดภัยและเป็นส่วนตัว';

  @override
  String get authRegisterTitle => 'สร้างบัญชีของคุณ';

  @override
  String get authRegisterSubtitle =>
      'เข้าร่วม HomeHQ เพื่อจัดการเรื่องในบ้านไว้ในที่เดียว';

  @override
  String get authFullName => 'ชื่อ-นามสกุล';

  @override
  String get authNameRequired => 'กรุณากรอกชื่อ';

  @override
  String get authNameShort => 'ชื่อสั้นเกินไป';

  @override
  String get authPasswordNew => 'กรุณากำหนดรหัสผ่าน';

  @override
  String get authPasswordMin => 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';

  @override
  String get authConfirmPassword => 'ยืนยันรหัสผ่าน';

  @override
  String get authConfirmRequired => 'กรุณายืนยันรหัสผ่าน';

  @override
  String get authPasswordMismatch => 'รหัสผ่านไม่ตรงกัน';

  @override
  String get authTerms =>
      'การสร้างบัญชีถือว่าคุณยอมรับข้อกำหนดและนโยบายความเป็นส่วนตัว';

  @override
  String get authCreating => 'กำลังสร้าง…';

  @override
  String get authCreateAccount => 'สร้างบัญชี';

  @override
  String get authSignInInstead => 'เข้าสู่ระบบแทน';

  @override
  String get authRegisterFailed => 'สร้างบัญชีไม่สำเร็จ กรุณาลองใหม่อีกครั้ง';

  @override
  String get authResetSendFailed =>
      'ส่งอีเมลรีเซ็ตไม่สำเร็จ กรุณาลองใหม่อีกครั้ง';

  @override
  String get authGenericFailed => 'เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง';

  @override
  String get authForgotTitle => 'ลืมรหัสผ่าน';

  @override
  String get authResetTitle => 'รีเซ็ตรหัสผ่านของคุณ';

  @override
  String get authResetHint =>
      'กรอกอีเมลของคุณ แล้วเราจะส่งลิงก์สำหรับรีเซ็ตให้';

  @override
  String get authSending => 'กำลังส่ง…';

  @override
  String get authSendLink => 'ส่งลิงก์รีเซ็ต';

  @override
  String get authBackToSignIn => 'กลับไปเข้าสู่ระบบ';

  @override
  String get authCheckInbox => 'ตรวจสอบกล่องจดหมายของคุณ';

  @override
  String get authSentBody =>
      'เราส่งลิงก์รีเซ็ตรหัสผ่านไปที่อีเมลของคุณแล้ว\nหากไม่พบ ให้ตรวจสอบในโฟลเดอร์สแปม';

  @override
  String get authResend => 'ส่งลิงก์อีกครั้ง';

  @override
  String get authUnexpected => 'เกิดข้อผิดพลาดที่ไม่คาดคิด';

  @override
  String get authUnknownError => 'เกิดข้อผิดพลาดที่ไม่ทราบสาเหตุ';

  @override
  String authNetworkError(String status) {
    return 'เชื่อมต่อเครือข่ายไม่ได้ ($status)';
  }

  @override
  String routeError(String error) {
    return 'เปิดหน้าไม่สำเร็จ: $error';
  }

  @override
  String get camEmptyTitle => 'ไม่พบกล้อง';

  @override
  String get camEmptyHint => 'เพิ่มกล้องในแอป Imou แล้วกล้องจะแสดงที่นี่';

  @override
  String get camDisabledTitle => 'ยังไม่ได้ตั้งค่ากล้อง';

  @override
  String get camDisabledHint =>
      'server ต้องมีข้อมูลบัญชีกล้องก่อน จึงจะแสดงกล้องที่นี่ได้';

  @override
  String get camOffline => 'ออฟไลน์';

  @override
  String get camLive => 'สด';

  @override
  String get camOfflineToast => 'กล้องนี้ออฟไลน์อยู่';

  @override
  String get camLoadFailed => 'โหลดรายการกล้องไม่สำเร็จ';

  @override
  String get camErrMisconfigured =>
      'บัญชีกล้องบน server ถูกปฏิเสธ กรุณาตรวจสอบการตั้งค่า';

  @override
  String get camErrLimit =>
      'บริการกล้องถึงขีดจำกัดการเรียกใช้แล้ว ลองใหม่ภายหลัง';

  @override
  String get camErrUnavailable => 'เชื่อมต่อบริการกล้องไม่ได้';

  @override
  String get camErrOffline => 'กล้องออฟไลน์อยู่';

  @override
  String get camPlayerFailed => 'เล่นภาพสดไม่ได้';

  @override
  String get camMute => 'ปิดเสียง';

  @override
  String get camUnmute => 'เปิดเสียง';

  @override
  String get camQuality => 'คุณภาพภาพ';

  @override
  String get camPausedIdle => 'หยุดชั่วคราวเพื่อประหยัดข้อมูล';

  @override
  String get camResume => 'ดูต่อ';

  @override
  String get camHumanDetect => 'ตรวจจับคนได้';

  @override
  String get camConnecting => 'กำลังเชื่อมต่อ…';

  @override
  String get camCameras => 'กล้องทั้งหมด';

  @override
  String get camSwipeHint => 'ปัดซ้าย-ขวาเพื่อเปลี่ยนกล้อง';

  @override
  String camPosition(int index, int total) {
    return '$index จาก $total';
  }

  @override
  String get camFullscreen => 'เต็มจอ';

  @override
  String get camExitFullscreen => 'ออกจากเต็มจอ';

  @override
  String get camPtzTitle => 'หันกล้อง';

  @override
  String get camPtzHint => 'กดค้างเพื่อหันต่อเนื่อง';

  @override
  String get camPtzUp => 'เงยขึ้น';

  @override
  String get camPtzDown => 'ก้มลง';

  @override
  String get camPtzLeft => 'หันซ้าย';

  @override
  String get camPtzRight => 'หันขวา';

  @override
  String get camPtzStop => 'หยุด';

  @override
  String get camZoomIn => 'ซูมเข้า';

  @override
  String get camZoomOut => 'ซูมออก';

  @override
  String get camPtzFailed => 'สั่งหันกล้องไม่สำเร็จ';

  @override
  String get camSettingsTitle => 'ตั้งค่ากล้อง';

  @override
  String get camSwitchPrivacy => 'โหมดส่วนตัว';

  @override
  String get camSwitchPrivacyHint => 'ปิดภาพจากกล้อง';

  @override
  String get camSwitchMotion => 'ตรวจจับการเคลื่อนไหว';

  @override
  String get camSwitchHuman => 'ตรวจจับคน';

  @override
  String get camSwitchFailed => 'เปลี่ยนการตั้งค่าไม่สำเร็จ';

  @override
  String get camSwitchesLoadFailed => 'โหลดการตั้งค่าไม่สำเร็จ';

  @override
  String get camNotSupported => 'กล้องตัวนี้ไม่รองรับฟังก์ชันนี้';

  @override
  String get camSwitchLight => 'ไฟของกล้อง';

  @override
  String get camSwitchLightHint => 'เปิดหรือปิดไฟที่ติดมากับกล้อง';

  @override
  String get camSwitchLightAuto => 'เปิดไฟเมื่อมีความเคลื่อนไหว';

  @override
  String get authSignedIn => 'เข้าสู่ระบบสำเร็จ';

  @override
  String get authSignedOut => 'ออกจากระบบแล้ว';

  @override
  String get homeGreetingMorning => 'สวัสดีตอนเช้า';

  @override
  String get homeGreetingAfternoon => 'สวัสดีตอนบ่าย';

  @override
  String get homeGreetingEvening => 'สวัสดีตอนเย็น';

  @override
  String get homeGreetingLate => 'สวัสดี';

  @override
  String get homeLastUsed => 'ใช้ล่าสุด';

  @override
  String get accountTitle => 'บัญชีของฉัน';

  @override
  String get accountOpen => 'เปิดหน้าบัญชีของฉัน';

  @override
  String get accountProfileSection => 'ข้อมูลส่วนตัว';

  @override
  String get accountName => 'ชื่อ';

  @override
  String get accountEmail => 'อีเมล';

  @override
  String get roleAdmin => 'ผู้ดูแล';

  @override
  String get roleMember => 'สมาชิก';

  @override
  String get accountEditName => 'แก้ไขชื่อ';

  @override
  String get accountNameRequired => 'กรุณากรอกชื่อ';

  @override
  String get accountNameSaved => 'อัปเดตชื่อแล้ว';

  @override
  String get accountSaveFailed => 'บันทึกไม่สำเร็จ ลองใหม่อีกครั้ง';

  @override
  String get accountSecuritySection => 'ความปลอดภัย';

  @override
  String get accountChangePassword => 'เปลี่ยนรหัสผ่าน';

  @override
  String get accountCurrentPassword => 'รหัสผ่านปัจจุบัน';

  @override
  String get accountNewPassword => 'รหัสผ่านใหม่';

  @override
  String get accountConfirmPassword => 'ยืนยันรหัสผ่านใหม่';

  @override
  String get accountPasswordTooShort => 'อย่างน้อย 6 ตัวอักษร';

  @override
  String get accountPasswordMismatch => 'รหัสผ่านไม่ตรงกัน';

  @override
  String get accountPasswordWrong => 'รหัสผ่านปัจจุบันไม่ถูกต้อง';

  @override
  String get accountPasswordChanged => 'เปลี่ยนรหัสผ่านแล้ว';

  @override
  String get accountPreferencesSection => 'การตั้งค่า';

  @override
  String get accountSignOut => 'ออกจากระบบ';

  @override
  String get accountCurrentRequired => 'กรุณากรอกรหัสผ่านปัจจุบัน';

  @override
  String camOnlineCount(int online, int total) {
    return 'ออนไลน์ $online จาก $total ตัว';
  }

  @override
  String get errNetwork =>
      'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ ตรวจสอบอินเทอร์เน็ตแล้วลองใหม่อีกครั้ง';

  @override
  String get errSession => 'เซสชันหมดอายุ กรุณาเข้าสู่ระบบอีกครั้ง';

  @override
  String get errForbidden => 'คุณไม่มีสิทธิ์ทำรายการนี้';

  @override
  String get errNotFound => 'ไม่พบข้อมูลที่ต้องการ';

  @override
  String get errServer => 'เซิร์ฟเวอร์มีปัญหา โปรดลองอีกครั้งในอีกสักครู่';

  @override
  String get billsNoMatchTitle => 'ไม่พบบิลที่ตรงกับที่ค้นหา';

  @override
  String get billsNoMatchHint => 'ลองคำอื่น หรือล้างตัวกรอง';

  @override
  String get medNoMatchTitle => 'ไม่พบยาที่ตรงกับที่ค้นหา';

  @override
  String get medNoMatchHint => 'ลองชื่ออื่น หรือล้างคำค้นหา';

  @override
  String get notesEmptyTitle => 'ยังไม่มีโน้ต';

  @override
  String get notesEmptyHint => 'กด + เพื่อเขียนโน้ตแรก';

  @override
  String get notesNoMatchHint => 'ลองคำอื่น หรือล้างตัวกรอง';

  @override
  String get commonMore => 'เพิ่มเติม';

  @override
  String get purchTake => 'รับไปซื้อ';

  @override
  String get purchMarkBought => 'ซื้อแล้ว';

  @override
  String get purchMarkDelivered => 'ได้รับของแล้ว';

  @override
  String get purchPaidTitle => 'จ่ายไปเท่าไร';

  @override
  String get purchPaidLabel => 'จำนวนเงินที่จ่าย';

  @override
  String get purchPaidInvalid => 'กรุณากรอกจำนวนเงิน';

  @override
  String get purchCancelPurchase => 'ยกเลิกรายการนี้';

  @override
  String get purchCancelAsk => 'ยกเลิกรายการนี้ใช่ไหม';

  @override
  String get purchCancelKeep => 'เก็บไว้';

  @override
  String get purchStatusUpdated => 'อัปเดตสถานะแล้ว';

  @override
  String get purchCancelled => 'ยกเลิกรายการแล้ว';
}
