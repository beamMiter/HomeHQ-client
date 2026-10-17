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

  @override
  String get toolAppliancesCaption => 'สั่งเปิด-ปิดไฟ ปลั๊ก และแอร์';

  @override
  String get applDisabledTitle => 'ยังไม่ได้ตั้งค่าเครื่องใช้ไฟฟ้า';

  @override
  String get applDisabledHint =>
      'server ต้องเชื่อมต่อแหล่งข้อมูลเครื่องใช้ไฟฟ้าก่อน จึงจะแสดงที่นี่ได้';

  @override
  String get applEmptyTitle => 'ไม่พบเครื่องใช้ไฟฟ้า';

  @override
  String get applEmptyHint =>
      'เครื่องใช้ไฟฟ้าที่เชื่อมต่อกับ server จะแสดงที่นี่';

  @override
  String get applLoadFailed => 'โหลดรายการเครื่องใช้ไฟฟ้าไม่สำเร็จ';

  @override
  String get applErrUnavailable => 'เชื่อมต่อบริการเครื่องใช้ไฟฟ้าไม่ได้';

  @override
  String get applErrMisconfigured =>
      'บัญชีเครื่องใช้ไฟฟ้าบน server ถูกปฏิเสธ กรุณาตรวจสอบการตั้งค่า';

  @override
  String get applErrLimit =>
      'บริการเครื่องใช้ไฟฟ้าถึงขีดจำกัดการเรียกใช้แล้ว ลองใหม่ภายหลัง';

  @override
  String get applErrOffline => 'เครื่องนี้ออฟไลน์อยู่';

  @override
  String get applErrNotSupported => 'เครื่องนี้ไม่รองรับคำสั่งนี้';

  @override
  String get applErrInvalid => 'ค่านี้ไม่ถูกต้อง';

  @override
  String get applOfflineToast => 'เครื่องนี้ออฟไลน์อยู่';

  @override
  String applSwitchFailed(String name) {
    return 'สั่ง $name ไม่สำเร็จ';
  }

  @override
  String get applOn => 'เปิด';

  @override
  String get applOff => 'ปิด';

  @override
  String get applOffline => 'ออฟไลน์';

  @override
  String get applNoRoom => 'อื่น ๆ';

  @override
  String get applCapPower => 'เปิด/ปิด';

  @override
  String get applCapBrightness => 'ความสว่าง';

  @override
  String get applCapTemperature => 'อุณหภูมิ';

  @override
  String get applCapMode => 'โหมด';

  @override
  String get applCapFanSpeed => 'ความแรงลม';

  @override
  String get applModeAuto => 'อัตโนมัติ';

  @override
  String get applModeCool => 'เย็น';

  @override
  String get applModeDry => 'ลดความชื้น';

  @override
  String get applModeFan => 'พัดลม';

  @override
  String get applModeHeat => 'ร้อน';

  @override
  String get applAdminOnly =>
      'เฉพาะผู้ดูแล (admin) เท่านั้นที่เปลี่ยนค่านี้ได้';

  @override
  String get applHeaterNote =>
      'เพื่อความปลอดภัย เครื่องนี้จะปิดเองหลังเปิดไว้สักพัก';

  @override
  String get applActivityTitle => 'กิจกรรมล่าสุด';

  @override
  String get applActivityEmpty => 'ยังไม่มีกิจกรรม';

  @override
  String get applActivityFailed => 'โหลดกิจกรรมไม่สำเร็จ';

  @override
  String get applAutoOffEvent => 'ระบบปิดให้อัตโนมัติ';

  @override
  String get applSomeone => 'ใครสักคน';

  @override
  String applEventOn(String who) {
    return '$who เปิดเครื่อง';
  }

  @override
  String applEventOff(String who) {
    return '$who ปิดเครื่อง';
  }

  @override
  String applEventSet(String who, String what, String value) {
    return '$who ตั้ง$whatเป็น $value';
  }

  @override
  String get applAddTitle => 'เพิ่มเครื่องใช้ไฟฟ้า';

  @override
  String get applAddButton => 'เพิ่มเครื่อง';

  @override
  String get applAddFirst => 'เพิ่มเครื่องแรกของคุณ';

  @override
  String get applAddAdminOnly =>
      'เฉพาะผู้ดูแล (admin) เท่านั้นที่เพิ่มเครื่องได้';

  @override
  String get applStepKind => 'เป็นเครื่องอะไร';

  @override
  String get applStepDetails => 'รายละเอียด';

  @override
  String get applStepConnect => 'การเชื่อมต่อ';

  @override
  String applStepOf(String step, String total) {
    return 'ขั้นที่ $step จาก $total';
  }

  @override
  String get applNext => 'ถัดไป';

  @override
  String get applBack => 'ย้อนกลับ';

  @override
  String get applKindAircon => 'แอร์';

  @override
  String get applKindLight => 'ไฟ';

  @override
  String get applKindFan => 'พัดลม';

  @override
  String get applKindPlug => 'ปลั๊กอัจฉริยะ';

  @override
  String get applKindHeater => 'เครื่องทำความร้อน';

  @override
  String get applKindOther => 'อื่น ๆ';

  @override
  String get applKindAirconHint =>
      'มีภาพลมเคลื่อนไหว อุณหภูมิ โหมด ความแรงลม และการส่ายลม';

  @override
  String get applKindLightHint => 'เปิด ปิด และปรับความสว่าง';

  @override
  String get applKindFanHint => 'เปิด ปิด และปรับความแรง';

  @override
  String get applKindPlugHint => 'เปิดและปิด';

  @override
  String get applKindHeaterHint => 'เปิดและปิด พร้อมระบบปิดเองเพื่อความปลอดภัย';

  @override
  String get applKindOtherHint => 'เปิดและปิด';

  @override
  String get applFieldName => 'ชื่อ';

  @override
  String get applFieldNameHint => 'เช่น แอร์ห้องนอน';

  @override
  String get applFieldRoom => 'ห้อง';

  @override
  String get applFieldBrand => 'ยี่ห้อ';

  @override
  String get applFieldModel => 'รุ่น';

  @override
  String get applFieldModelHint =>
      'เช่น FTKM25 ดูได้จากสติกเกอร์ที่เครื่องในห้องหรือที่รีโมท';

  @override
  String get applFieldOptional => 'ไม่บังคับ';

  @override
  String get applFieldRequired => 'ตั้งชื่อให้เครื่องด้วย';

  @override
  String get applRoomLiving => 'ห้องนั่งเล่น';

  @override
  String get applRoomBedroom => 'ห้องนอน';

  @override
  String get applRoomKitchen => 'ห้องครัว';

  @override
  String get applRoomBathroom => 'ห้องน้ำ';

  @override
  String get applRoomStudy => 'ห้องทำงาน';

  @override
  String get applRoomGarage => 'โรงรถ';

  @override
  String get applRoomOther => 'ห้องอื่น…';

  @override
  String get applRoomCustomHint => 'ชื่อห้อง';

  @override
  String get applConnTitle => 'จะควบคุมเครื่องนี้อย่างไร';

  @override
  String get applConnDemo => 'จำลอง';

  @override
  String get applConnDemoSummary =>
      'ลองปุ่มควบคุมและภาพเคลื่อนไหว ไม่ได้สั่งเครื่องจริง';

  @override
  String get applConnWifi => 'แอร์มี Wi-Fi ในตัว';

  @override
  String get applConnWifiSummary =>
      'แอร์ หรืออะแดปเตอร์ Wi-Fi ของแอร์ คุยกับคลาวด์ของยี่ห้อนั้น';

  @override
  String get applConnIr => 'รีโมทอินฟราเรดอัจฉริยะ';

  @override
  String get applConnIrSummary =>
      'ตัวส่งสัญญาณ IR ผ่าน Wi-Fi ส่งคำสั่งแทนรีโมท';

  @override
  String get applConnHa => 'Home Assistant';

  @override
  String get applConnHaSummary =>
      'ใช้แอร์ที่เพิ่มไว้ใน Home Assistant อยู่แล้ว';

  @override
  String get applConnSoon => 'เร็ว ๆ นี้';

  @override
  String get applConnNeed => 'สิ่งที่ต้องมี';

  @override
  String get applConnUnavailable =>
      'การเชื่อมต่อนี้ยังไม่พร้อมใช้งาน เพิ่มแบบจำลองเพื่อลองใช้ไปก่อนได้';

  @override
  String get applReqDemo1 => 'ไม่ต้องมีอะไร server จำลองให้';

  @override
  String get applReqWifi1 =>
      'แอร์ที่มี Wi-Fi ในตัว หรือติดอะแดปเตอร์ Wi-Fi ของยี่ห้อนั้น';

  @override
  String get applReqWifi2 =>
      'เครือข่าย Wi-Fi 2.4 GHz (แอร์ส่วนใหญ่ใช้ 5 GHz ไม่ได้)';

  @override
  String get applReqWifi3 =>
      'แอปของยี่ห้อนั้นที่ตั้งค่าแอร์เครื่องนี้แล้ว (Daikin Mobile, MELCloud, Comfort Cloud, ThinQ, SmartThings…)';

  @override
  String get applReqWifi4 => 'ไดรเวอร์ของ HomeHQ สำหรับยี่ห้อนั้นบน server';

  @override
  String get applReqIr1 =>
      'รีโมท IR อัจฉริยะแบบ Wi-Fi (Tuya / Smart Life, Broadlink, Sonoff, Xiaomi…)';

  @override
  String get applReqIr2 =>
      'วางให้เห็นช่องรับสัญญาณของแอร์ ห่างไม่เกินไม่กี่เมตร';

  @override
  String get applReqIr3 =>
      'รุ่นแอร์ของคุณอยู่ในคลังรหัสของรีโมท หรือเรียนรู้รหัสจากรีโมทเดิมได้';

  @override
  String get applReqIr4 => 'เครือข่าย Wi-Fi 2.4 GHz และบัญชีของแอปรีโมทตัวนั้น';

  @override
  String get applReqIrNote =>
      'IR ส่งทางเดียว แอปจึงอ่านไม่ได้ว่าแอร์ทำอะไรอยู่จริง รู้แค่ว่าสั่งอะไรไปล่าสุด';

  @override
  String get applReqHa1 =>
      'Home Assistant ที่รันอยู่ในเครือข่ายของคุณ และเพิ่มแอร์เป็นอุปกรณ์ climate แล้ว';

  @override
  String get applReqHa2 =>
      'Long-lived access token จากโปรไฟล์ใน Home Assistant';

  @override
  String get applReqHa3 => 'server ของ HomeHQ ต้องเข้าถึง Home Assistant ได้';

  @override
  String applAddedToast(String name) {
    return 'เพิ่ม $name แล้ว';
  }

  @override
  String get applAddFailed => 'เพิ่มเครื่องไม่สำเร็จ';

  @override
  String get applRemove => 'ลบเครื่องนี้';

  @override
  String applRemoveAsk(String name) {
    return 'ลบ $name ใช่ไหม';
  }

  @override
  String get applRemoveBody =>
      'แอปจะลืมเครื่องนี้ ไม่ได้ปิดหรือเปลี่ยนค่าอะไรบนเครื่องจริง';

  @override
  String applRemovedToast(String name) {
    return 'ลบ $name แล้ว';
  }

  @override
  String get applRemoveFailed => 'ลบไม่สำเร็จ';

  @override
  String get applCapSwing => 'ส่ายลม';

  @override
  String get applSimulated => 'จำลอง';

  @override
  String applAirconOn(String mode, String temp) {
    return 'แอร์เปิดอยู่ โหมด$mode $temp';
  }

  @override
  String get applAirconOff => 'แอร์ปิดอยู่';

  @override
  String get toolDashboardCaption => 'เงินไปไหนบ้าง รวมบิลและของที่ซื้อ';

  @override
  String get dashTitle => 'รายจ่าย';

  @override
  String dashSpentIn(String month) {
    return 'ใช้จ่ายใน$month';
  }

  @override
  String dashUp(String pct, String month) {
    return 'เพิ่มขึ้น $pct% จาก$month';
  }

  @override
  String dashDown(String pct, String month) {
    return 'ลดลง $pct% จาก$month';
  }

  @override
  String dashSame(String month) {
    return 'เท่ากับ$month';
  }

  @override
  String dashNoPrev(String month) {
    return '$monthไม่มีรายจ่าย';
  }

  @override
  String get dashBills => 'บิล';

  @override
  String get dashPurchases => 'ของที่ซื้อ';

  @override
  String get dashBillsPaid => 'บิลที่จ่ายแล้ว';

  @override
  String get dashBought => 'ซื้อแล้ว';

  @override
  String get dashStillToPay => 'ค้างจ่าย';

  @override
  String dashBillCount(int count) {
    return '$count บิล';
  }

  @override
  String get dashOverdue => 'เลยกำหนด';

  @override
  String get dashNoneOverdue => 'ไม่มีบิลเลยกำหนด';

  @override
  String get dashPlanned => 'ของที่วางแผนจะซื้อ';

  @override
  String dashItemCount(int count) {
    return '$count รายการ';
  }

  @override
  String get dashTrendTitle => '6 เดือนล่าสุด';

  @override
  String get dashChartView => 'กราฟ';

  @override
  String get dashTableView => 'ตาราง';

  @override
  String get dashColMonth => 'เดือน';

  @override
  String get dashColTotal => 'รวม';

  @override
  String get dashByType => 'บิลที่จ่ายแล้ว แยกตามประเภท';

  @override
  String get dashByCategory => 'ของที่ซื้อ แยกตามหมวด';

  @override
  String get dashNoBillsPaid => 'เดือนนี้ยังไม่ได้จ่ายบิล';

  @override
  String get dashNoPurchases => 'เดือนนี้ยังไม่ได้ซื้อของ';

  @override
  String get dashCategoryOther => 'ไม่ระบุหมวด';

  @override
  String get dashUpcomingTitle => 'บิลที่ต้องจ่ายถัดไป';

  @override
  String get dashNoUpcoming => 'ไม่มีบิลค้างจ่าย';

  @override
  String get dashDueToday => 'ครบกำหนดวันนี้';

  @override
  String get dashDueTomorrow => 'ครบกำหนดพรุ่งนี้';

  @override
  String dashDueIn(int days) {
    return 'อีก $days วัน';
  }

  @override
  String dashOverdueBy(int days) {
    return 'เลยกำหนด $days วัน';
  }

  @override
  String get dashViewAll => 'ดูทั้งหมด';

  @override
  String dashExcluded(int count) {
    return '$count รายการที่ซื้อเป็นสกุลเงินอื่น ไม่รวมในยอด';
  }

  @override
  String get dashLoadFailed => 'โหลดตัวเลขรายจ่ายไม่สำเร็จ';

  @override
  String dashEmptyTitle(String month) {
    return '$monthยังไม่มีรายจ่าย';
  }

  @override
  String get dashEmptyHint => 'จ่ายบิลหรือบันทึกว่าซื้อของแล้ว จะแสดงที่นี่';

  @override
  String get dashThisMonth => 'เดือนนี้';

  @override
  String get dashPrevMonth => 'เดือนก่อน';

  @override
  String get dashNextMonth => 'เดือนถัดไป';

  @override
  String dashChartLabel(String month, String bills, String purchases) {
    return '$month: บิล $bills ของที่ซื้อ $purchases';
  }

  @override
  String get dashPaceTitle => 'จังหวะการใช้จ่าย';

  @override
  String get dashPaceSub => 'ยอดสะสมรายวัน เทียบกับเดือนก่อน';

  @override
  String dashPaceNow(int day, String amount) {
    return 'ถึงวันที่ $day: $amount';
  }

  @override
  String dashPaceMore(String amount) {
    return 'มากกว่าช่วงเดียวกันของเดือนก่อน $amount';
  }

  @override
  String dashPaceLess(String amount) {
    return 'น้อยกว่าช่วงเดียวกันของเดือนก่อน $amount';
  }

  @override
  String get dashPaceSame => 'เท่ากับช่วงเดียวกันของเดือนก่อน';

  @override
  String dashPaceLabel(String now, String prev) {
    return 'ยอดสะสม: เดือนนี้ $now ช่วงเดียวกันของเดือนก่อน $prev';
  }

  @override
  String get dashDonutCenter => 'จ่ายแล้ว';

  @override
  String get dashTrendEmpty =>
      'ยังไม่มีข้อมูล จ่ายบิลหรือบันทึกว่าซื้อของแล้ว จะแสดงที่นี่';

  @override
  String dashPaceAt(int day, String now, String prev) {
    return 'วันที่ $day: $now · เดือนก่อน $prev';
  }

  @override
  String dashPaceAtPrev(int day, String prev) {
    return 'วันที่ $day: เดือนก่อน $prev';
  }

  @override
  String get applStatusOn => 'เปิดอยู่';

  @override
  String get applStatusOff => 'ปิดอยู่';

  @override
  String get applStatusTurningOn => 'กำลังเปิด…';

  @override
  String get applStatusTurningOff => 'กำลังปิด…';

  @override
  String get applStatusUnconfirmed => 'ยังไม่ยืนยัน';

  @override
  String applStatusOnSince(String time, String duration) {
    return 'เปิดตั้งแต่ $time · $duration';
  }

  @override
  String applStatusOffSince(String time, String duration) {
    return 'ปิดตั้งแต่ $time · $duration';
  }

  @override
  String applStatusOfflineBody(String state) {
    return 'ติดต่อเครื่องไม่ได้ตอนนี้ สถานะล่าสุดที่รู้: $state';
  }

  @override
  String applStatusAutoOff(String time, String left) {
    return 'จะปิดเองเวลา $time (อีก $left)';
  }

  @override
  String get applStatusUnconfirmedBody =>
      'ส่งคำสั่งแล้ว แต่เครื่องยังไม่ยืนยัน กดตรวจสอบอีกครั้งเพื่อความแน่ใจ';

  @override
  String get applCheckedJustNow => 'ตรวจสอบเมื่อสักครู่';

  @override
  String applCheckedAgo(String ago) {
    return 'ตรวจสอบเมื่อ $ago ที่แล้ว';
  }

  @override
  String applCheckFailed(String time) {
    return 'ตรวจสอบไม่สำเร็จ กำลังแสดงสถานะล่าสุดเมื่อ $time';
  }

  @override
  String get applCheckNow => 'ตรวจสอบตอนนี้';

  @override
  String applStatusFilterNone(String status) {
    return 'ตอนนี้ไม่มีเครื่องที่$status';
  }

  @override
  String applStatusSummaryLabel(int onCount, int offCount, int offlineCount) {
    return 'เปิดอยู่ $onCount ปิดอยู่ $offCount ออฟไลน์ $offlineCount';
  }

  @override
  String applHomeOn(int count, int total) {
    return 'เปิดอยู่ $count จาก $total เครื่อง';
  }

  @override
  String applHomeOffline(int count) {
    return 'ออฟไลน์ $count';
  }

  @override
  String get applDurUnderMinute => 'ไม่ถึงนาที';

  @override
  String applDurSeconds(int n) {
    return '$n วินาที';
  }

  @override
  String applDurMinutes(int n) {
    return '$n นาที';
  }

  @override
  String applDurHours(int h, int m) {
    return '$h ชม. $m นาที';
  }

  @override
  String applDurHoursOnly(int h) {
    return '$h ชม.';
  }

  @override
  String applDurDays(int d, int h) {
    return '$d วัน $h ชม.';
  }

  @override
  String get applKindCooler => 'พัดลมไอเย็น';

  @override
  String get applKindCoolerHint =>
      'ปรับแรงลม ส่ายซ้าย–ขวา เปิดน้ำทำความเย็น และโหมด';

  @override
  String get applCapCooling => 'ทำความเย็น';

  @override
  String get applModeNormal => 'ปกติ';

  @override
  String get applModeNatural => 'ลมธรรมชาติ';

  @override
  String get applModeSleep => 'นอนหลับ';

  @override
  String applLightOn(String brightness) {
    return 'ไฟเปิดอยู่ ความสว่าง $brightness';
  }

  @override
  String get applLightOff => 'ไฟปิดอยู่';

  @override
  String applCoolerOn(int speed) {
    return 'พัดลมไอเย็นเปิดอยู่ แรงลม $speed';
  }

  @override
  String applCoolerOnCooling(int speed) {
    return 'พัดลมไอเย็นเปิดอยู่ แรงลม $speed ทำความเย็นอยู่';
  }

  @override
  String get applCoolerOff => 'พัดลมไอเย็นปิดอยู่';

  @override
  String get applStatusAll => 'ทั้งหมด';

  @override
  String applSinceShort(String time) {
    return 'ตั้งแต่ $time';
  }

  @override
  String applAutoOffShort(String left) {
    return 'ปิดเองใน $left';
  }

  @override
  String applLastKnown(String state) {
    return 'ล่าสุด: $state';
  }

  @override
  String applOfflineAlert(int count) {
    return 'ติดต่อไม่ได้ $count เครื่อง';
  }

  @override
  String get applStatusTitle => 'สถานะ';

  @override
  String get applHeaterOn => 'ฮีตเตอร์เปิดอยู่';

  @override
  String applHeaterOnAutoOff(String left) {
    return 'ฮีตเตอร์เปิดอยู่ จะปิดเองในอีก $left';
  }

  @override
  String get applHeaterOff => 'ฮีตเตอร์ปิดอยู่';

  @override
  String get applHeaterOffIn => 'ปิดเองใน';
}
