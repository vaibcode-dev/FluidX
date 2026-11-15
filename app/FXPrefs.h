#import <Foundation/Foundation.h>

extern NSString *const FXDomain;
extern NSString *const FXReloadNotification;

/// Общий домен настроек — тот же, что читает твик в SpringBoard.
NSUserDefaults *FXDefaults(void);

/// Сохранить значение и сразу сообщить твику, что настройки изменились.
void FXSetValue(NSString *key, id value);

/// Убрать все настройки (сброс к значениям по умолчанию).
void FXResetAll(void);

/// Разослать уведомление о перезагрузке настроек.
void FXNotifyReload(void);

/// Записать короткий отчёт о том, куда приложение реально пишет настройки:
/// /var/mobile/FluidX-app.txt. Нужен, если настройки не доходят до твика.
void FXWriteDiagnostic(NSString *tag);
